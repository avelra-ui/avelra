## Generic webview window adapter for experimental platforms.
##
## Uses only the cross-platform webview C API. There is no native loading
## overlay yet: the window is shown by webview_create(), and the page may
## briefly appear empty before the first frame. Linux keeps its GTK adapter.

import std/json

import adapters/webview/api
import adapters/webview/bridge
import application/dispatcher
import ports/loading_port

type
  AppWindow* = ref object
    ## Owns the native webview handle and the bridge reference.
    webview*: Webview
    bridge: WebviewBridge

proc createAppWindow*(title: string; width, height: int;
                      iconPath = ""): AppWindow =
  ## Creates the window and sets its initial title and geometry.
  let webview = webviewCreate(0, nil)
  if webview == nil:
    raise newException(OSError, "failed to create the webview")

  discard webviewSetTitle(webview, title.cstring)
  discard webviewSetSize(webview, cint(width), cint(height),
                         cint(WebviewHintNone))

  result = AppWindow(webview: webview)

proc installLoading*(window: AppWindow): LoadingPort =
  ## Experimental platforms have no native loading overlay yet.
  LoadingPort(hide: proc() = discard)

proc bindNativeCall*(window: AppWindow; dispatcher: Dispatcher) =
  ## Registers `window.nativeCall` and keeps the bridge alive with the window.
  window.bridge = installBridge(window.webview, dispatcher)

proc startEventPump*(window: AppWindow; pump: proc() {.closure.}) =
  ## No cross-platform timer yet; extension events are delivered during calls.
  discard

proc emitEvent*(window: AppWindow; eventName: string; data: JsonNode) =
  if window.bridge != nil:
    window.bridge.emitEvent(eventName, data)

proc close*(window: AppWindow) =
  ## Experimental platforms close through the native window API.
  discard webviewTerminate(window.webview)

proc navigate*(window: AppWindow; url: string) =
  ## Loads the client URL. Bindings must already be installed.
  discard webviewNavigate(window.webview, url.cstring)

proc showAndRun*(window: AppWindow) =
  ## Runs the platform event loop until the window is closed.
  try:
    discard webviewRun(window.webview)
  finally:
    discard webviewDestroy(window.webview)
