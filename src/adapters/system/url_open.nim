## OS-backed implementation of UrlOpenPort.

import std/[os, osproc]

import ports/url_open_port

proc runHandler(command: string; args: openArray[string]): bool =
  ## Waits for the system handler so its exit status is observable.
  if findExe(command).len == 0:
    return false
  var process: Process
  try:
    process = startProcess(command, args = args,
      options = {poUsePath, poStdErrToStdOut})
    result = waitForExit(process) == 0
  except OSError:
    result = false
  finally:
    if process != nil:
      close(process)

proc systemUrlOpen*(): UrlOpenPort =
  ## Opens URLs with the platform's default browser.
  UrlOpenPort(
    openUrl: proc(url: string): bool =
      when defined(linux):
        runHandler("xdg-open", [url])
      elif defined(macosx):
        runHandler("open", [url])
      elif defined(windows):
        runHandler("cmd", ["/c", "start", "", url])
      else:
        false
  )
