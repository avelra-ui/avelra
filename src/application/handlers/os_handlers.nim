## Built-in `os.*` methods.

import std/json

import application/dispatcher
import domain/native_call

proc handleGetEnv(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Reads an environment variable through the EnvPort abstraction.
  let key = call.data.field("key").getStr("")
  result = ok(%ctx.env.getEnv(key))

proc registerOsHandlers*(dispatcher: Dispatcher) =
  ## Registers the built-in `os.*` namespace.
  dispatcher.register("os.getEnv", handleGetEnv)
