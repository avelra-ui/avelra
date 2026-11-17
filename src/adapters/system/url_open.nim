## OS-backed implementation of UrlOpenPort.

import std/[os, osproc]

import ports/url_open_port

when defined(windows):
  import std/winlean

const
  HandlerWaitMs = 2000

type
  UrlOpenLaunch* = object
    ## Result of handing a URL to the platform handler.
    launched*: bool
    process*: Process
    ## On Windows ShellExecuteW has no child process, so this is nil.

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

when defined(windows):
  proc shellExecuteUrl(url: string): bool =
    ## Hands the URL to the registered Windows handler without a command shell.
    let operation = newWideCString("open")
    let target = newWideCString(url)
    result = shellExecuteW(Handle(0), operation, target, nil, nil, 1) > 32

proc startUrlOpen*(url: string): UrlOpenLaunch =
  ## Starts the system URL handler.
  ##
  ## Linux/macOS return a process for the main-thread pump. Windows uses
  ## ShellExecuteW and returns no process after a successful handoff.
  when defined(windows):
    try:
      result = UrlOpenLaunch(launched: shellExecuteUrl(url))
    except CatchableError:
      result = UrlOpenLaunch(launched: false)
  elif defined(linux):
    try:
      result = UrlOpenLaunch(
        launched: true,
        process: startProcess("xdg-open", args = [url],
          options = {poUsePath, poStdErrToStdOut})
      )
    except OSError:
      result = UrlOpenLaunch(launched: false)
  elif defined(macosx):
    try:
      result = UrlOpenLaunch(
        launched: true,
        process: startProcess("open", args = [url],
          options = {poUsePath, poStdErrToStdOut})
      )
    except OSError:
      result = UrlOpenLaunch(launched: false)
  else:
    result = UrlOpenLaunch(launched: false)

proc systemUrlOpen*(): UrlOpenPort =
  ## Opens URLs with the platform's default handler.
  UrlOpenPort(
    openUrl: proc(url: string): bool =
      when defined(windows):
        shellExecuteUrl(url)
      elif defined(linux):
        runHandler("xdg-open", [url])
      elif defined(macosx):
        runHandler("open", [url])
      else:
        false
  )
