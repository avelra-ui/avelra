## Extension sidecar process and JSONL JSON-RPC transport.
##
## One process per extension. A reader thread feeds a line channel so the core
## can handle responses, events, and timeouts without blocking the UI.

import std/[json, os, osproc, streams, times]

import cli/config
import avelra_version

const
  MaxMessageBytes* = 1024 * 1024
  CoreProtocolVersion* = 1
  CoreVersion* = AvelraVersion
  InitializeTimeoutMs* = 5000
  DefaultRequestTimeoutMs* = 30000

type
  ExtensionState* = enum
    esStopped
    esStarting
    esReady
    esStopping
    esCrashed

  ExtensionHandshake* = object
    name*: string
    version*: string
    protocol*: int
    methods*: seq[string]

  ExtensionEventHandler* = proc(name: string; data: JsonNode) {.closure.}

  ExtensionHostError* = object of CatchableError
  ExtensionStartError* = object of ExtensionHostError
  ExtensionProtocolError* = object of ExtensionHostError
  ExtensionTimeoutError* = object of ExtensionHostError
  ExtensionRpcError* = object of ExtensionHostError
    code*: int
    data*: JsonNode

  ReaderArgs = object
    process: Process
    lines: ptr Channel[string]

  ExtensionHost* = ref object
    config*: ExtensionConfig
    appDir*: string
    state*: ExtensionState
    handshake*: ExtensionHandshake
    process: Process
    nextId: int
    lines: Channel[string]
    reader: Thread[ReaderArgs]
    readerStarted: bool
    onEvent*: ExtensionEventHandler

proc readerMain(args: ReaderArgs) {.thread.} =
  try:
    while true:
      let line = args.process.outputStream.readLine()
      if line.len == 0:
        break
      try:
        args.lines[].send(line)
      except CatchableError:
        break
  except CatchableError:
    discard
  try:
    args.lines[].send("")
  except CatchableError:
    discard

proc startReader(host: ExtensionHost) =
  host.lines.open()
  var args = ReaderArgs(process: host.process, lines: addr host.lines)
  createThread(host.reader, readerMain, args)
  host.readerStarted = true

proc stopReader(host: ExtensionHost) =
  if host.readerStarted:
    try:
      host.lines.close()
    except CatchableError:
      discard
    joinThread(host.reader)
    host.readerStarted = false

proc sendMessage(host: ExtensionHost; node: JsonNode) =
  if host.process == nil:
    raise newException(ExtensionHostError, "extension process is not running")
  let stream = host.process.inputStream
  try:
    stream.writeLine($node)
    stream.flush()
  except CatchableError as exc:
    host.state = esCrashed
    raise newException(ExtensionHostError,
      "extension pipe is closed: " & exc.msg)

proc nextLine(host: ExtensionHost; timeoutMs: int): string =
  let started = epochTime()
  while true:
    let item = host.lines.tryRecv()
    if item.dataAvailable:
      if item.msg.len == 0:
        host.state = esCrashed
        raise newException(ExtensionHostError, "extension closed stdout")
      if item.msg.len > MaxMessageBytes:
        raise newException(ExtensionProtocolError,
          "extension message exceeds " & $MaxMessageBytes & " bytes")
      return item.msg
    if host.process == nil or not host.process.running():
      host.state = esCrashed
      raise newException(ExtensionHostError, "extension process exited")
    if timeoutMs > 0 and (epochTime() - started) * 1000.0 >= float(timeoutMs):
      raise newException(ExtensionTimeoutError,
        "extension request timed out after " & $timeoutMs & " ms")
    sleep(5)

proc parseMessage(line: string): JsonNode =
  try:
    result = parseJson(line)
  except JsonParsingError as exc:
    raise newException(ExtensionProtocolError,
      "invalid extension JSON: " & exc.msg)
  if result.kind != JObject:
    raise newException(ExtensionProtocolError, "extension message must be an object")

proc dispatchEvent(host: ExtensionHost; node: JsonNode) =
  if host.onEvent == nil:
    return
  let params = node{"params"}
  if params.kind != JObject:
    raise newException(ExtensionProtocolError, "extension event has no params")
  let name = params{"name"}.getStr("")
  if name.len == 0:
    raise newException(ExtensionProtocolError, "extension event has no name")
  host.onEvent(name, params{"data"})

proc isEvent(node: JsonNode): bool =
  node.hasKey("method") and node["method"].kind == JString and
    node["method"].getStr() == "event"

proc readResponse(host: ExtensionHost; expectedId: int; timeoutMs: int): JsonNode =
  while true:
    let node = parseMessage(host.nextLine(timeoutMs))
    if isEvent(node):
      host.dispatchEvent(node)
      continue
    if not node.hasKey("id") or node["id"].kind != JInt or
        node["id"].getInt() != expectedId:
      raise newException(ExtensionProtocolError, "extension response id mismatch")
    return node

proc parseHandshake(host: ExtensionHost; response: JsonNode) =
  if response.hasKey("error"):
    let error = response["error"]
    raise newException(ExtensionProtocolError,
      "extension initialize failed: " & error{"message"}.getStr("unknown error"))
  if not response.hasKey("result") or response["result"].kind != JObject:
    raise newException(ExtensionProtocolError, "initialize response has no result")

  let result = response["result"]
  if not result.hasKey("name") or result["name"].kind != JString:
    raise newException(ExtensionProtocolError, "initialize result has no name")
  host.handshake.name = result["name"].getStr()
  if result.hasKey("version") and result["version"].kind == JString:
    host.handshake.version = result["version"].getStr()
  if not result.hasKey("protocol") or result["protocol"].kind != JInt:
    raise newException(ExtensionProtocolError, "initialize result has no protocol")
  host.handshake.protocol = result["protocol"].getInt()
  if host.handshake.protocol != host.config.protocol:
    raise newException(ExtensionProtocolError,
      "extension protocol mismatch: expected " & $host.config.protocol &
      ", got " & $host.handshake.protocol)
  if result.hasKey("methods"):
    if result["methods"].kind != JArray:
      raise newException(ExtensionProtocolError, "initialize methods must be an array")
    for methodName in result["methods"]:
      if methodName.kind != JString or methodName.getStr().len == 0:
        raise newException(ExtensionProtocolError, "invalid extension method")
      host.handshake.methods.add methodName.getStr()

proc startProcessFor(host: ExtensionHost) =
  let command = commandFor(host.config)
  if command.len == 0:
    raise newException(ExtensionStartError, "extension command is empty")
  let executable = command[0]
  let args = if command.len > 1: command[1 .. ^1] else: @[]
  var options: set[ProcessOption] = {}
  when defined(windows):
    options.incl poDaemon
  if not executable.isAbsolute and not executable.contains('/') and
      not executable.contains('\\'):
    options.incl poUsePath

  try:
    host.process = startProcess(
      executable,
      workingDir = host.appDir,
      args = args,
      options = options
    )
  except OSError as exc:
    host.state = esStopped
    raise newException(ExtensionStartError,
      "cannot start extension '" & host.config.id & "': " & exc.msg)
  host.startReader()

proc stopExtension*(host: ExtensionHost) =
  ## Sends shutdown, then terminates/kills the process if needed.
  if host == nil or host.process == nil:
    return
  if host.state in {esReady, esStarting}:
    try:
      host.sendMessage(%*{"jsonrpc": "2.0", "method": "shutdown"})
    except CatchableError:
      discard
  host.state = esStopping
  try:
    host.process.inputStream.close()
  except CatchableError:
    discard
  discard host.process.waitForExit(2000)
  if host.process.running():
    host.process.terminate()
    discard host.process.waitForExit(1000)
  if host.process.running():
    host.process.kill()
    discard host.process.waitForExit(1000)
  host.process.close()
  host.process = nil
  host.stopReader()
  host.state = esStopped

proc startExtension*(config: ExtensionConfig; appDir: string;
                     onEvent: ExtensionEventHandler = nil): ExtensionHost =
  ## Starts the sidecar and performs `initialize`.
  result = ExtensionHost(
    config: config,
    appDir: absolutePath(appDir),
    state: esStarting,
    nextId: 2,
    onEvent: onEvent
  )
  try:
    result.startProcessFor()
    result.sendMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {
        "protocol": CoreProtocolVersion,
        "coreVersion": CoreVersion,
        "appDir": result.appDir
      }
    })
    let response = result.readResponse(1, InitializeTimeoutMs)
    result.parseHandshake(response)
    result.state = esReady
  except CatchableError:
    result.stopExtension()
    raise

proc request*(host: ExtensionHost; methodName: string; params: JsonNode = nil;
              timeoutMs = DefaultRequestTimeoutMs): JsonNode =
  ## Synchronous request/response. Events received while waiting are dispatched.
  if host.state != esReady:
    raise newException(ExtensionHostError, "extension is not ready")
  let id = host.nextId
  inc host.nextId
  var message = %*{"jsonrpc": "2.0", "id": id, "method": methodName}
  if params != nil:
    message["params"] = params
  host.sendMessage(message)
  var response: JsonNode
  try:
    response = host.readResponse(id, timeoutMs)
  except ExtensionTimeoutError:
    try:
      host.sendMessage(%*{
        "jsonrpc": "2.0",
        "method": "cancel",
        "params": {"id": id}
      })
    except CatchableError:
      discard
    raise
  if response.hasKey("error"):
    let error = response["error"]
    var exc = newException(ExtensionRpcError,
      error{"message"}.getStr("extension request failed"))
    exc.code = error{"code"}.getInt(-32000)
    exc.data = error{"data"}
    raise exc
  if response.hasKey("result"):
    return response["result"]
  newJNull()

proc pumpEvents*(host: ExtensionHost) =
  ## Drains queued extension events on the core/main thread.
  if host == nil or host.process == nil:
    return
  while true:
    let item = host.lines.tryRecv()
    if not item.dataAvailable:
      break
    if item.msg.len == 0:
      host.state = esCrashed
      break
    let node = parseMessage(item.msg)
    if isEvent(node):
      host.dispatchEvent(node)
