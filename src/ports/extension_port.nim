## Port for routing `ext.*` native calls to user extensions.
##
## The application layer stays independent of sidecar/JSON-RPC details.

import std/json

import domain/native_call

type
  ExtensionPort* = ref object
    dispatch*: proc(methodName: string; payload: JsonNode): NativeResult {.closure.}
