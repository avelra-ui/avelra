## Built-in `app.*` methods.

import std/json

import application/dispatcher
import domain/native_call

proc handlePing(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Bridge smoke test: echoes the request payload back to the page.
  result = ok(%*{
    "message": "pong",
    "echo": call.data,
    "runtime": "nim"
  })

proc handleReady(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## UI lifecycle signal: the page has painted its first content.
  if ctx.loading.hide != nil:
    ctx.loading.hide()
  result = ok()

proc handleExit(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Requests a clean window close; the platform run loop performs cleanup.
  if ctx.quit.quit == nil:
    return fail(ErrMethodNotFound, "app.exit is not available on this platform")
  ctx.quit.quit()
  result = ok()

proc registerAppHandlers*(dispatcher: Dispatcher) =
  ## Registers the built-in `app.*` namespace.
  dispatcher.register("app.ping", handlePing)
  dispatcher.register("app.ready", handleReady)
  dispatcher.register("app.exit", handleExit)
