## Built-in `os.*` methods.

import std/[json, strutils]

import application/dispatcher
import domain/native_call

proc handleGetEnv(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Reads an environment variable through the EnvPort abstraction.
  let key = call.data.field("key").getStr("")
  result = ok(%ctx.env.getEnv(key))

proc handleOpenExternal(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Opens only explicit http(s) URLs; other schemes stay out of the browser.
  let url = call.data.field("url").getStr("")
  if not (url.startsWith("https://") or url.startsWith("http://")):
    return fail(ErrInvalidRequest, "url must start with http:// or https://")
  if ctx.external.open == nil:
    return fail(ErrInvalidRequest, "external URL handler is unavailable")
  if ctx.external.open(url):
    ok()
  else:
    fail(ErrInvalidRequest, "could not open external URL")

proc registerOsHandlers*(dispatcher: Dispatcher) =
  ## Registers the built-in `os.*` namespace.
  dispatcher.register("os.getEnv", handleGetEnv)
  dispatcher.register("os.openExternal", handleOpenExternal)
