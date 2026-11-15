## OS-backed implementation of UrlOpenPort.

import std/[os, osproc]

import ports/url_open_port

const
  HandlerWaitMs = 2000

proc runHandler(command: string; args: openArray[string]): bool =
  ## Waits for the system handler. The legacy dispatcher path uses this
  ## synchronously; the public os.openUrl path uses startUrlOpen + main pump.
  if findExe(command).len == 0:
    return false
  var process: Process
  try:
    process = startProcess(command, args = args,
      options = {poUsePath, poStdErrToStdOut})
    result = waitForExit(process, HandlerWaitMs) == 0
  except OSError:
    result = false
  finally:
    if process != nil:
      close(process)

proc startUrlOpen*(url: string): Process =
  ## Starts the system browser handler and returns its process handle.
  when defined(linux):
    result = startProcess("xdg-open", args = [url],
      options = {poUsePath, poStdErrToStdOut})
  elif defined(macosx):
    result = startProcess("open", args = [url],
      options = {poUsePath, poStdErrToStdOut})
  elif defined(windows):
    result = startProcess("cmd", args = ["/c", "start", "", url],
      options = {poUsePath, poStdErrToStdOut})

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
