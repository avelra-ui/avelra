## Integration tests for the local std/net static server.
##
## They bind a real localhost socket, so they do not need a GUI or WebView.

import std/[net, os, strutils, unittest]

import adapters/http/[resource_store, static_server]

proc request(port: Port; httpMethod, path, host, accept: string): string =
  let client = newSocket(buffered = false)
  try:
    client.connect("127.0.0.1", port, timeout = 1000)
    var raw = httpMethod & " " & path & " HTTP/1.1\r\n" &
      "Host: " & host & "\r\n" &
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

let root = getTempDir() / ("avelra-static-server-" & $getCurrentProcessId())
removeDir(root)
createDir(root)
writeFile(root / "index.html", "<h1>Hello static</h1>")
writeFile(root / "app.js", "console.log('ok');")

let store = newDirectoryStore(root)
let server = startStaticServer(store, workerCount = 2)
try:
  let host = "127.0.0.1:" & $int(server.port)
  let token = server.url.split('/')[3]
  let prefix = "/" & token & "/"

  proc tokenPath(path: string): string =
    if path == "/":
      prefix
    else:
      prefix & path[1 .. ^1]

  suite "static server":
    test "serves index.html at the root":
      let response = request(server.port, "GET", tokenPath("/"), host, "text/html")
      check response.startsWith("HTTP/1.1 200")
      check response.contains("Content-Type: text/html")
      check response.contains("Hello static")

    test "serves JavaScript with the right MIME type":
      let response = request(server.port, "GET", tokenPath("/app.js"), host, "*/*")
      check response.startsWith("HTTP/1.1 200")
      check response.contains("Content-Type: text/javascript")

    test "HEAD returns headers without a body":
      let response = request(server.port, "HEAD", tokenPath("/app.js"), host, "*/*")
      check response.startsWith("HTTP/1.1 200")
      check not response.contains("console.log")

    test "the path token has 128 bits":
      check token.len == 32

    test "requests without the token are not found":
      let response = request(server.port, "GET", "/", host, "text/html")
      check response.startsWith("HTTP/1.1 404")

    test "wrong tokens are not found":
      let response = request(server.port, "GET", "/wrong/index.html", host, "*/*")
      check response.startsWith("HTTP/1.1 404")

    test "unknown assets return 404":
      let response = request(server.port, "GET", tokenPath("/missing.js"), host, "*/*")
      check response.startsWith("HTTP/1.1 404")

    test "extension-less HTML routes use the SPA fallback":
      let response = request(server.port, "GET", tokenPath("/dashboard"), host, "text/html")
      check response.startsWith("HTTP/1.1 200")
      check response.contains("Hello static")

    test "traversal is forbidden":
      let response = request(server.port, "GET", tokenPath("/../secret"), host, "*/*")
      check response.startsWith("HTTP/1.1 403")

    test "foreign Host headers are forbidden":
      let response = request(server.port, "GET", tokenPath("/"), "evil.example", "text/html")
      check response.startsWith("HTTP/1.1 403")

    test "unsupported methods are rejected":
      let response = request(server.port, "POST", tokenPath("/"), host, "*/*")
      check response.startsWith("HTTP/1.1 405")
finally:
  server.stop()
  removeDir(root)
