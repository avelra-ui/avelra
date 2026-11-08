## Application-level dispatcher.
##
## It maps a NativeCall to a handler and executes it. It must not import
## webview, GTK, or any other transport/platform module.

import std/[strutils, tables]

import domain/native_call
import ports/[env_port, extension_port, loading_port, quit_port]

type
  HandlerContext* = ref object
    ## Shared dependencies passed to every handler. Extending this object is the
    ## preferred way to give handlers access to new ports.
    env*: EnvPort
    loading*: LoadingPort
    extensions*: ExtensionPort
    quit*: QuitPort

  Handler* = proc(call: NativeCall; ctx: HandlerContext): NativeResult
    ## Implements one native method. Must not import platform or transport code.

  Dispatcher* = ref object
    ## Method registry plus the context handed to each handler.
    handlers*: Table[string, Handler]
    ctx*: HandlerContext

proc newHandlerContext*(env: EnvPort; loading: LoadingPort;
                        extensions: ExtensionPort = nil;
                        quit: QuitPort = QuitPort()): HandlerContext =
  ## Builds the dependency bundle used by handlers.
  HandlerContext(env: env, loading: loading, extensions: extensions,
                 quit: quit)

proc newDispatcher*(ctx: HandlerContext): Dispatcher =
  ## Creates an empty registry; handlers are added with `register`.
  Dispatcher(handlers: initTable[string, Handler](), ctx: ctx)

proc register*(dispatcher: Dispatcher; nativeMethod: string; handler: Handler) =
  ## Registers or replaces the handler for `nativeMethod`.
  dispatcher.handlers[nativeMethod] = handler

proc dispatch*(dispatcher: Dispatcher; call: NativeCall): NativeResult =
  ## Routes the call to its handler and converts unexpected exceptions into a
  ## protocol error, so no Nim exception can cross the bridge boundary.
  if not dispatcher.handlers.hasKey(call.nativeMethod):
    if call.nativeMethod.startsWith("ext.") and dispatcher.ctx.extensions != nil:
      try:
        return dispatcher.ctx.extensions.dispatch(call.nativeMethod, call.data)
      except CatchableError as exc:
        return fail(ErrInvalidRequest, exc.msg)
    return fail(ErrMethodNotFound, "unknown method: " & call.nativeMethod)

  try:
    result = dispatcher.handlers[call.nativeMethod](call, dispatcher.ctx)
  except CatchableError as exc:
    result = fail(ErrInvalidRequest, exc.msg)
