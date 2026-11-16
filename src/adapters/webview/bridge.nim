## Webview bridge adapter: translates `webview_bind` calls into NativeCall,
## invokes the application dispatcher, and returns a JSON envelope.

import std/[json, osproc]

import adapters/system/url_open
import adapters/webview/api
import application/dispatcher
import domain/[native_call, url_policy]

type
  UrlOpenPending = object
    id: string
    process: Process

  WebviewBridge* = ref object
    ## Owns the native webview handle and the dispatcher for the lifetime of
    ## the bind callback. The callback receives only a raw pointer.
    webview: Webview
    dispatcher: Dispatcher
    urlPending: seq[UrlOpenPending]

proc emitEvent*(bridge: WebviewBridge; eventName: string; data: JsonNode) =
  ## Delivers one namespaced event to the page; no-op before JS bootstrap.
  let event = %*{"name": eventName, "data": data}
  let script = "if (window.__avelraEmit) { window.__avelraEmit(" &
    $event & "); }"
  discard webviewEval(bridge.webview, script.cstring)

proc completeUrlOpen(bridge: WebviewBridge; id: string; code: int) =
  ## Resolves one background URL request on the UI thread.
  let response =
    if code == 0: ok()
    else: fail(ErrOperationFailed, "could not open URL")
  let payload = $toJson(response)
  discard webviewReturn(bridge.webview, id.cstring, 0, payload.cstring)

proc pumpAsync*(bridge: WebviewBridge) =
  ## Polls background URL processes on the UI thread and resolves Promises.
  ## No worker ever calls webview_return.
  var pending: seq[UrlOpenPending]
  for item in bridge.urlPending:
    var code = -1
    try:
      code = peekExitCode(item.process)
    except OSError:
      code = 1
    if code == -1:
      pending.add(item)
      continue
    try:
      close(item.process)
    except OSError:
      discard
    completeUrlOpen(bridge, item.id, code)
  bridge.urlPending = pending

proc handleNativeCall(id: cstring; req: cstring; arg: pointer) {.cdecl.} =
  ## Parses the JS argument array, dispatches it, and always resolves the JS
  ## Promise with a protocol envelope (status 0), including error cases.
  ## os.openUrl starts an OS process and is completed by the main event pump.
  let bridge = cast[WebviewBridge](arg)
  var call: NativeCall

  try:
    call = parseCall($req)
  except CatchableError as exc:
    let payload = $toJson(fail(ErrInvalidRequest, exc.msg))
    discard webviewReturn(bridge.webview, id, 0, payload.cstring)
    return

  if call.nativeMethod == "os.openUrl":
    let url = call.data.field("url").getStr("")
    if not isAllowedUrl(url):
      let payload = $toJson(fail(ErrInvalidRequest,
        "url must use http, https or mailto"))
      discard webviewReturn(bridge.webview, id, 0, payload.cstring)
      return
    try:
      let launch = startUrlOpen(url)
      if not launch.launched:
        let payload = $toJson(fail(ErrOperationFailed, "could not open URL"))
        discard webviewReturn(bridge.webview, id, 0, payload.cstring)
        return
      if launch.process == nil:
        let payload = $toJson(ok())
        discard webviewReturn(bridge.webview, id, 0, payload.cstring)
        return
      bridge.urlPending.add(UrlOpenPending(id: $id, process: launch.process))
      return
    except OSError:
      let payload = $toJson(fail(ErrOperationFailed, "could not open URL"))
      discard webviewReturn(bridge.webview, id, 0, payload.cstring)
      return

  let response = bridge.dispatcher.dispatch(call)
  let payload = $toJson(response)
  discard webviewReturn(bridge.webview, id, 0, payload.cstring)

const coreApiScript* = """
(function () {
  const call = (method, data) => window.__avelraNativeCall({ method, data });
  window.avelra = {
    app: {
      ping: (data) => call("app.ping", data),
      ready: () => call("app.ready"),
      healthCheck: () => call("app.healthCheck"),
      exit: () => call("app.exit")
    },
    os: {
      getEnv: (key) => call("os.getEnv", { key }),
      openUrl: (url) => call("os.openUrl", { url })
    }
  };
})();
"""

proc installBridge*(webview: Webview; dispatcher: Dispatcher): WebviewBridge =
  ## Registers the internal `__avelraNativeCall` transport and the public
  ## `window.avelra` namespace. The namespace is a user script so it is
  ## installed on every navigation, not only on the initial about:blank page.
  ## The returned reference must be kept alive until the webview is destroyed.
  ## The transport is intentionally not public; it becomes callExt in 0.5.
  result = WebviewBridge(webview: webview, dispatcher: dispatcher)
  discard webviewBind(webview, "__avelraNativeCall", handleNativeCall,
                      cast[pointer](result))
  discard webviewInit(webview, coreApiScript.cstring)
