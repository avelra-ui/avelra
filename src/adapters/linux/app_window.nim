## Linux application window adapter.
##
## Composes the platform pieces: webview window creation, initial geometry,
## the GTK loading overlay, and the webview bridge.

import std/[json, os]

import adapters/linux/gtk_api
import adapters/linux/loading_overlay
import adapters/webview/api
import adapters/webview/bridge
import application/dispatcher
import ports/loading_port

type
  AppWindow* = ref object
    ## Owns the native window, the bridge, and the loading overlay.
    ## The private fields keep references alive for the whole run loop.
    webview*: Webview
    gtkWindow: pointer
    width: int
    height: int
    bridge: WebviewBridge
    loading: LoadingOverlay
    iconPath: string
    eventPump: proc() {.closure.}

proc applyWindowIcon(window: GtkWindow; iconPath: string) =
  if window == nil or iconPath.len == 0 or not fileExists(iconPath):
    return
  discard gtkWindowSetIconFromFile(window, iconPath.cstring, nil)

proc createAppWindow*(title: string; width, height: int;
                      iconPath = ""): AppWindow =
  ## Creates the webview window in a hidden state with the requested geometry.
  ## The caller must install the overlay, bind the bridge, load HTML, and only
  ## then call `showAndRun`.
  # WebKitGTK >= 2.42 uses a DMA-BUF renderer by default. On machines without
  # a usable DRM/EGL device it can block before the first frame.
  if not existsEnv("WEBKIT_DISABLE_DMABUF_RENDERER") and
      not existsEnv("AVELRA_USE_GPU"):
    putEnv("WEBKIT_DISABLE_DMABUF_RENDERER", "1")

  if iconPath.len > 0 and fileExists(iconPath):
    discard gtkWindowSetDefaultIconFromFile(iconPath.cstring, nil)

  let webview = webviewCreate(0, nil)
  if webview == nil:
    raise newException(OSError, "failed to create the webview")

  # webview_create() shows the window immediately. Hide it for the few
  # milliseconds needed to set geometry and install the loading overlay, so
  # the first visible frame is already the branded 600x400 window.
  let gtkWindow = webviewGetWindow(webview)
  if gtkWindow != nil:
    gtkWidgetHide(cast[GtkWidget](gtkWindow))

  discard webviewSetTitle(webview, title.cstring)
  discard webviewSetSize(webview, cint(width), cint(height),
                         cint(WebviewHintNone))

  if gtkWindow != nil:
    gtkWindowResize(cast[GtkWidget](gtkWindow), cint(width), cint(height))
    applyWindowIcon(cast[GtkWindow](gtkWindow), iconPath)

  result = AppWindow(
    webview: webview,
    gtkWindow: gtkWindow,
    width: width,
    height: height,
    iconPath: iconPath
  )

proc installLoading*(window: AppWindow): LoadingPort =
  ## Installs the native loading overlay and adapts it to the application port.
  ## When native handles are unavailable, returns a no-op port.
  if window.gtkWindow == nil:
    return LoadingPort(hide: proc() = discard)

  let webviewWidget = webviewGetNativeHandle(
    window.webview, cint(WebviewNativeHandleUiWidget))
  window.loading = installLoadingOverlay(window.gtkWindow, webviewWidget)

  # Reparenting can reset the size request; restore the requested geometry.
  if window.gtkWindow != nil:
    gtkWindowResize(cast[GtkWidget](window.gtkWindow),
                    cint(window.width), cint(window.height))

  result = window.loading.toLoadingPort()

proc bindNativeCall*(window: AppWindow; dispatcher: Dispatcher) =
  ## Registers `window.nativeCall` and stores the bridge in the window so the
  ## callback cannot outlive its owner.
  # The bridge owns the dispatcher reference for the lifetime of the window.
  window.bridge = installBridge(window.webview, dispatcher)

proc eventPumpCallback(data: pointer): cint {.cdecl.} =
  let window = cast[AppWindow](data)
  if window != nil and window.eventPump != nil:
    try:
      window.eventPump()
    except CatchableError:
      discard
  1

proc startEventPump*(window: AppWindow; pump: proc() {.closure.}) =
  ## Pumps queued extension events from the GTK main loop.
  window.eventPump = pump
  if window.gtkWindow != nil:
    discard gTimeoutAdd(50, eventPumpCallback, cast[pointer](window))

proc emitEvent*(window: AppWindow; eventName: string; data: JsonNode) =
  if window.bridge != nil:
    window.bridge.emitEvent(eventName, data)

proc navigate*(window: AppWindow; url: string) =
  ## Loads the client URL. Bindings must already be installed.
  discard webviewNavigate(window.webview, url.cstring)

proc close*(window: AppWindow) =
  ## Closes the GTK window from the UI thread.
  if window.gtkWindow != nil:
    gtkWindowClose(window.gtkWindow)

proc showAndRun*(window: AppWindow) =
  ## Shows the prepared window and runs the GTK main loop until it is closed.
  if window.gtkWindow != nil:
    gtkWidgetShowAll(cast[GtkWidget](window.gtkWindow))
    applyWindowIcon(cast[GtkWindow](window.gtkWindow), window.iconPath)

  try:
    discard webviewRun(window.webview)
  finally:
    discard webviewDestroy(window.webview)
