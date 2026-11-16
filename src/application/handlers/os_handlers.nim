## Built-in `os.*` methods.

import std/json

import application/dispatcher
import domain/[native_call, url_policy]

proc handleGetEnv(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Reads an environment variable through the EnvPort abstraction.
  let key = call.data.field("key").getStr("")
  result = ok(%ctx.env.getEnv(key))

proc handleOpenUrl(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Opens only explicit http(s) URLs; other schemes stay out of the browser.
  let url = call.data.field("url").getStr("")
  if not isAllowedUrl(url):
    return fail(ErrInvalidRequest, "url must use http, https or mailto")
  if ctx.urlOpen.openUrl == nil:
    return fail(ErrOperationFailed, "URL handler is unavailable")
  if ctx.urlOpen.openUrl(url):
    ok()
  else:
    fail(ErrOperationFailed, "could not open URL")

proc registerOsHandlers*(dispatcher: Dispatcher) =
  ## Registers the built-in `os.*` namespace.
  dispatcher.register("os.getEnv", handleGetEnv)
  dispatcher.register("os.openUrl", handleOpenUrl)
