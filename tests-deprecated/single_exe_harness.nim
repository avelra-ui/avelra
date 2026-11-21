## Headless test harness for the packed resource server.
##
## Prints the server URL and waits for `exit` (or EOF) on stdin. It does not
## create a WebView, so it can run in tests without a display.

import std/[os, syncio]

import adapters/http/[resource_store, static_server]

when isMainModule:
  try:
    let store = openResourceStore(getAppFilename(), "client")
    let server = startStaticServer(store)
    stdout.writeLine(server.url)
    flushFile(stdout)

    while true:
      let line = stdin.readLine()
      if line.len == 0 or line == "exit":
        break
    server.stop()
  except CatchableError as exc:
    stderr.writeLine("single-exe harness: " & exc.msg)
    quit(1)
