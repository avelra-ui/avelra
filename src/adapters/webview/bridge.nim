## Webview bridge adapter: translates `webview_bind` calls into NativeCall,
## invokes the application dispatcher, and returns a JSON envelope.

import std/json

import adapters/webview/api
import application/dispatcher
import domain/native_call

type
  WebviewBridge* = ref object
    ## Owns the native webview handle and the dispatcher for the lifetime of
    ## the bind callback. The callback receives only a raw pointer.
    webview: Webview
    dispatcher: Dispatcher

proc emitEvent*(bridge: WebviewBridge; eventName: string; data: JsonNode) =
  ## Delivers one namespaced event to the page; no-op before JS bootstrap.
  let event = %*{"name": eventName, "data": data}
  let script = "if (window.__avelraEmit) { window.__avelraEmit(" &
    $event & "); }"
  discard webviewEval(bridge.webview, script.cstring)

proc handleNativeCall(id: cstring; req: cstring; arg: pointer) {.cdecl.} =
  ## Parses the JS argument array, dispatches it, and always resolves the JS
  ## Promise with a protocol envelope (status 0), including error cases.
  let bridge = cast[WebviewBridge](arg)
  var response: NativeResult

  try:
    response = bridge.dispatcher.dispatch(parseCall($req))
  except CatchableError as exc:
    response = fail(ErrInvalidRequest, exc.msg)

  let payload = $toJson(response)
  discard webviewReturn(bridge.webview, id, 0, payload.cstring)

proc installBridge*(webview: Webview; dispatcher: Dispatcher): WebviewBridge =
  ## Registers the single `nativeCall` binding. The returned reference must be
  ## kept alive until the webview is destroyed.
  result = WebviewBridge(webview: webview, dispatcher: dispatcher)
  discard webviewBind(webview, "nativeCall", handleNativeCall,
                      cast[pointer](result))
