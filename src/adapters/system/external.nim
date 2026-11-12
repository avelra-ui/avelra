## OS-backed implementation of ExternalPort.

import std/osproc

import ports/external_port

proc systemExternal*(): ExternalPort =
  ## Starts the system URL handler without blocking the GUI thread.
  ExternalPort(
    open: proc(url: string): bool =
      try:
        when defined(linux):
          discard startProcess("xdg-open", args = [url],
            options = {poUsePath, poDaemon})
        elif defined(macosx):
          discard startProcess("open", args = [url],
            options = {poUsePath, poDaemon})
        elif defined(windows):
          discard startProcess("cmd", args = ["/c", "start", "", url],
            options = {poUsePath, poDaemon})
        else:
          return false
        true
      except OSError:
        false
  )
