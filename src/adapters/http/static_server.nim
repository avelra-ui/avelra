## Local static HTTP server for client assets.
##
## Uses only `std/net`: one accept thread, a fixed worker pool, and a channel
## that transfers sockets by pointer. It is intentionally limited to GET/HEAD,
## `Connection: close`, and localhost access.

import std/[atomics, net, options, strutils, sysrand]

import adapters/http/[resource_store, static_paths]

const
  MaxWorkers = 8
  DefaultWorkers = 4
  ReadTimeoutMs = 5000
  MaxHeaderBytes = 16 * 1024
  BindErrorSize* = 256

type
  StaticServer* = ref object
    port*: Port
    token: string
    store: ResourceStore
    bindError: array[BindErrorSize, char]
    running: Atomic[bool]
    portChan: Channel[int]
    workChan: Channel[pointer]
    serverThread: Thread[ServerArgs]
    workers: array[MaxWorkers, Thread[WorkerArgs]]
    workerCount: int
    started: bool

  ServerArgs = object
    portChan: ptr Channel[int]
    workChan: ptr Channel[pointer]
    running: ptr Atomic[bool]
    workerCount: int
    errorBuffer: ptr array[BindErrorSize, char]

  WorkerArgs = object
    workChan: ptr Channel[pointer]
    store: ResourceStore
    token: cstring
    port: int

proc sendResponse(client: Socket; status, contentType, body: string;
                  headOnly = false; extraHeaders = "") =
  var header = "HTTP/1.1 " & status & "\r\n" &
    "Content-Type: " & contentType & "\r\n" &
    "Content-Length: " & $body.len & "\r\n" &
    "Connection: close\r\n" &
    "Cache-Control: no-store\r\n"
  if extraHeaders.len > 0:
    header.add extraHeaders
  header.add "\r\n"

  # Empty flags make a disconnected peer raise instead of retrying forever.
  client.send(header, flags = {})
  if not headOnly:
    client.send(body, flags = {})

proc sendError(client: Socket; status, message: string; extraHeaders = "") =
  sendResponse(client, status, "text/plain; charset=utf-8", message & "\n",
               extraHeaders = extraHeaders)

proc sendStoreError(client: Socket; error: ResourceError) =
  case error
  of notFound:
    sendError(client, "404 Not Found", "File not found")
  of forbidden:
    sendError(client, "403 Forbidden", "Path is not allowed")
  of ioError:
    sendError(client, "500 Internal Server Error", "Unable to read file")

proc readHeaders(client: Socket): tuple[ok: bool, raw: string] =
  var data = ""
  while data.len < MaxHeaderBytes:
    # `recv` with a size reads exactly `size` bytes; one byte at a time keeps
    # short browser requests responsive without a blocking read-ahead.
    let ch = client.recv(1, ReadTimeoutMs)
    if ch.len == 0:
      return (false, "")
    data.add ch
    if data.endsWith("\r\n\r\n"):
      return (true, data)
  (false, "")

proc generateToken(): string =
  ## 128-bit path token; hex keeps it URL- and log-friendly.
  var bytes: array[16, byte]
  if not urandom(bytes):
    raise newException(OSError, "cannot generate static server token")
  for value in bytes:
    result.add toHex(value, 2).toLowerAscii()

proc stripToken(relative, token: string): Option[string] =
  if relative == token:
    return some("")
  if relative.startsWith(token & "/"):
    return some(relative[token.len + 1 .. ^1])
  none(string)

proc handleClient(client: Socket; store: ResourceStore; token: cstring;
                  port: int) =
  let (ok, raw) = readHeaders(client)
  if not ok:
    sendError(client, "400 Bad Request", "Malformed request")
    return

  let headerEnd = raw.find("\r\n\r\n")
  let lines = raw[0 ..< headerEnd].split("\r\n")
  if lines.len == 0:
    sendError(client, "400 Bad Request", "Missing request line")
    return

  let requestLine = lines[0].split(' ')
  if requestLine.len != 3:
    sendError(client, "400 Bad Request", "Invalid request line")
    return

  let httpMethod = requestLine[0]
  let target = requestLine[1]
  let version = requestLine[2]

  var host = ""
  var accept = ""
  for i in 1 ..< lines.len:
    let colon = lines[i].find(':')
    if colon <= 0:
      continue
    let name = lines[i][0 ..< colon].strip.toLowerAscii()
    let value = lines[i][colon + 1 .. ^1].strip
    case name
    of "host":
      host = value.toLowerAscii()
    of "accept":
      accept = value
    else:
      discard

  if not version.startsWith("HTTP/1."):
    sendError(client, "400 Bad Request", "Unsupported HTTP version")
    return

  let expectedHost = "127.0.0.1:" & $port
  let expectedLocalhost = "localhost:" & $port
  if host.len == 0:
    sendError(client, "400 Bad Request", "Host header is required")
    return
  if host != expectedHost and host != expectedLocalhost:
    sendError(client, "403 Forbidden", "Invalid Host header")
    return

  if httpMethod != "GET" and httpMethod != "HEAD":
    sendError(client, "405 Method Not Allowed", "Only GET and HEAD are supported",
              extraHeaders = "Allow: GET, HEAD\r\n")
    return

  let parsed = parseRequestPath(target)
  if not parsed.valid:
    sendError(client, "403 Forbidden", "Invalid path")
    return

  let relative = stripToken(parsed.relative, $token)
  if relative.isNone:
    sendError(client, "404 Not Found", "File not found")
    return

  var lookup = store.get(relative.get)
  if not lookup.found and lookup.error == notFound and
      isSpaFallback(relative.get, accept):
    lookup = store.get(IndexFile)

  if not lookup.found:
    sendStoreError(client, lookup.error)
    return

  sendResponse(client, "200 OK", lookup.resource.contentType, lookup.resource.data,
               headOnly = httpMethod == "HEAD")

proc setBindError*(buffer: var array[BindErrorSize, char]; message: string) =
  ## Copies a bind/listen error into a fixed-size, NUL-terminated buffer.
  let count = min(message.len, BindErrorSize - 1)
  if count > 0:
    copyMem(addr buffer[0], unsafeAddr message[0], count)
  buffer[count] = '\0'

proc bindErrorText*(buffer: array[BindErrorSize, char]): string =
  ## Reads a fixed-size buffer without relying on `$cstring` over-reads.
  var length = 0
  while length < BindErrorSize and buffer[length] != '\0':
    inc length
  result = newString(length)
  if length > 0:
    copyMem(addr result[0], unsafeAddr buffer[0], length)

proc formatBindFailure*(reason: string): string =
  ## User-facing message; empty reasons still produce a useful line.
  let detail = if reason.len == 0: "unknown error" else: reason
  "cannot start static server on 127.0.0.1: " & detail

proc serverMain(args: ServerArgs) {.thread.} =
  var listener: Socket
  try:
    listener = newSocket()
    listener.setSockOpt(OptReuseAddr, true)
    listener.bindAddr(Port(0), "127.0.0.1")
    listener.listen()
    let (_, boundPort) = listener.getLocalAddr()
    args.portChan[].send(int(boundPort))
  except CatchableError as exc:
    setBindError(args.errorBuffer[], exc.msg)
    args.portChan[].send(-1)
    return

  while args.running[].load():
    var client: Socket
    try:
      listener.accept(client)
    except OSError:
      break

    if not args.running[].load():
      client.close()
      break

    # The worker takes ownership of the socket; GC_ref keeps it alive while
    # the raw pointer travels through the channel.
    GC_ref(client)
    args.workChan[].send(cast[pointer](client))

  listener.close()
  for _ in 0 ..< args.workerCount:
    args.workChan[].send(cast[pointer](nil))

proc workerMain(args: WorkerArgs) {.thread.} =
  while true:
    let raw = args.workChan[].recv()
    if raw == nil:
      break
    let client = cast[Socket](raw)
    try:
      handleClient(client, args.store, args.token, args.port)
    except CatchableError:
      discard
    finally:
      client.close()
      GC_unref(client)

proc startStaticServer*(store: ResourceStore; workerCount = DefaultWorkers): StaticServer =
  ## Starts the server on a random localhost port and returns its handle.
  if workerCount < 1 or workerCount > MaxWorkers:
    raise newException(ValueError, "workerCount must be between 1 and 8")
  if store.kind == directory and store.root == nil:
    raise newException(ValueError, "directory store is not initialized")
  if store.kind == embedded and store.archive == nil:
    raise newException(ValueError, "embedded store is not initialized")

  let token = generateToken()
  result = StaticServer(store: store, workerCount: workerCount, token: token)
  result.portChan.open()
  result.workChan.open()
  result.running.store(true)

  var serverArgs = ServerArgs(
    portChan: addr result.portChan,
    workChan: addr result.workChan,
    running: addr result.running,
    workerCount: workerCount,
    errorBuffer: addr result.bindError
  )
  createThread(result.serverThread, serverMain, serverArgs)

  let bound = result.portChan.recv()
  if bound <= 0:
    let reason = bindErrorText(result.bindError)
    result.running.store(false)
    joinThread(result.serverThread)
    result.portChan.close()
    result.workChan.close()
    close(result.store)
    raise newException(OSError, formatBindFailure(reason))

  result.port = Port(bound)

  let workerArgs = WorkerArgs(
    workChan: addr result.workChan,
    store: result.store,
    token: cstring(result.token),
    port: bound
  )
  for i in 0 ..< workerCount:
    createThread(result.workers[i], workerMain, workerArgs)

  result.started = true

proc isRunning*(server: StaticServer): bool =
  ## Reports whether the accept thread is still active.
  server.running.load()

proc url*(server: StaticServer): string =
  ## Base URL for the WebView.
  "http://127.0.0.1:" & $int(server.port) & "/" & server.token & "/"

proc stop*(server: StaticServer) =
  ## Stops accepting, drains workers, and releases resources.
  if server == nil or not server.started:
    return

  server.running.store(false)
  try:
    let wake = newSocket()
    wake.connect("127.0.0.1", server.port, timeout = 1000)
    wake.close()
  except CatchableError:
    discard

  joinThread(server.serverThread)
  for _ in 0 ..< server.workerCount:
    server.workChan.send(cast[pointer](nil))
  for i in 0 ..< server.workerCount:
    joinThread(server.workers[i])

  server.portChan.close()
  server.workChan.close()
  close(server.store)
  server.started = false
