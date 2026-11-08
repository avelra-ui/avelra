## OS-backed implementation of EnvPort.
##
## Ports stay platform-agnostic; concrete access to the process environment
## belongs to an adapter.

import std/os

import ports/env_port

proc systemEnv*(): EnvPort =
  ## Production adapter backed by the process environment.
  EnvPort(
    getEnv: proc(key: string): string =
      os.getEnv(key)
  )
