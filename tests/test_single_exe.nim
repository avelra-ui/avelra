## End-to-end test: pack a headless harness and serve it without client/.

import std/[net, os, osproc, streams, strutils, unittest, uri]

import support

proc request(port: Port; path, accept: string): string =
  let client = newSocket(buffered = false)
  try:
    client.connect("127.0.0.1", port, timeout = 1000)
    var raw = "GET " & path & " HTTP/1.1\r\n" &
      "Host: 127.0.0.1:" & $int(port) & "\r\n" &
      "Connection: close\r\n"
    if accept.len > 0:
      raw.add "Accept: " & accept & "\r\n"
    raw.add "\r\n"
    client.send(raw)
    while true:
      try:
        let chunk = client.recv(1, 2000)
        if chunk.len == 0:
          break
        result.add chunk
      except TimeoutError:
        break
  finally:
    client.close()

proc startHarness(executable, workingDir: string): tuple[process: Process, port: Port, basePath: string] =
  let process = startProcess(
    executable,
    workingDir = workingDir,
    options = {poStdErrToStdOut}
  )
  let line = process.outputStream.readLine()
  if line.len == 0:
    let details = process.outputStream.readAll()
    process.close()
    raise newException(IOError, "harness did not print URL: " & details)
  let uri = parseUri(line)
  let token = uri.path.strip(chars = {'/'})
  result = (process, Port(parseInt(uri.port)), "/" & token & "/")

proc stopHarness(process: Process) =
  try:
    process.inputStream.writeLine("exit")
    process.inputStream.flush()
  except CatchableError:
    discard
  discard process.waitForExit()
  process.close()

let root = getTempDir() / ("avelra-single-exe-" & $getCurrentProcessId())
let source = root / "source"
let sourceClient = source / "client"
let runDir = root / "run"
let fallbackDir = root / "fallback"
let fallbackClient = fallbackDir / "client"
let packed = root / "packed"
let fixtureExt = when defined(windows): ".exe" else: ""
let harness = absolutePath(testBin("single_exe_harness" & fixtureExt))

removeDir(root)
createDir(sourceClient / "assets")
createDir(runDir)
createDir(fallbackClient)
writeFile(sourceClient / "index.html", "<h1>Packed</h1>")
writeFile(sourceClient / "assets" / "app.js", "console.log('packed');")
writeFile(fallbackClient / "index.html", "<h1>Fallback</h1>")

let packCommand = quoteShellCommand([
  packPath(),
  "--binary", harness,
  "--client", sourceClient,
  "--output", packed
])
let packResult = execCmdEx(packCommand)
if packResult.exitCode != 0:
  removeDir(root)
  raise newException(IOError, "pack failed: " & packResult.output)

var packedHarness = startHarness(packed, runDir)
try:
  suite "packed single-executable":
    test "serves index.html without client/":
      check not dirExists(runDir / "client")
      let response = request(packedHarness.port, packedHarness.basePath, "text/html")
      check response.startsWith("HTTP/1.1 200")
      check response.contains("Packed")

    test "serves an asset with MIME type":
      let response = request(packedHarness.port, packedHarness.basePath & "assets/app.js", "*/*")
      check response.startsWith("HTTP/1.1 200")
      check response.contains("Content-Type: text/javascript")
      check response.contains("console.log('packed')")

    test "serves the SPA fallback":
      let response = request(packedHarness.port, packedHarness.basePath & "dashboard", "text/html")
      check response.startsWith("HTTP/1.1 200")
      check response.contains("Packed")

    test "returns 404 for a missing asset":
      let response = request(packedHarness.port, packedHarness.basePath & "missing.js", "*/*")
      check response.startsWith("HTTP/1.1 404")

    test "falls back to client/ when no payload exists":
      var fallbackHarness = startHarness(harness, fallbackDir)
      try:
        let response = request(fallbackHarness.port, fallbackHarness.basePath, "text/html")
        check response.startsWith("HTTP/1.1 200")
        check response.contains("Fallback")
      finally:
        stopHarness(fallbackHarness.process)
finally:
  stopHarness(packedHarness.process)
  removeDir(root)
