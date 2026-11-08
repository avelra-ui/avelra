## Port for reading environment variables.
##
## The application layer depends on this abstraction. The OS-backed
## implementation lives in `adapters/system/env.nim`; tests provide a fake.

type
  EnvPort* = object
    ## Returns an environment variable or an empty string when it is unset.
    getEnv*: proc(key: string): string {.closure.}
