## Raw C API of webview/webview 0.12.0.
##
## This module contains declarations only: no policy, no UI, no JSON.

type
  Webview* = pointer
    ## Opaque handle returned by webview_create.
  WebviewBindFn* = proc(id: cstring; req: cstring; arg: pointer) {.cdecl.}
    ## Callback invoked by a bound JS function. `req` is a JSON array of the
    ## JS arguments; the result must be delivered with webview_return.

const
  # No size hints: width and height are the initial window size.
  WebviewHintNone* = 0
  # Native handle kind for the WebKit widget (WEBVIEW_NATIVE_HANDLE_KIND_UI_WIDGET).
  WebviewNativeHandleUiWidget* = 1

proc webviewCreate*(debug: cint; window: pointer): Webview
  {.cdecl, importc: "webview_create".}

proc webviewTerminate*(w: Webview): cint
  {.cdecl, importc: "webview_terminate".}

proc webviewDestroy*(w: Webview): cint
  {.cdecl, importc: "webview_destroy".}

proc webviewRun*(w: Webview): cint
  {.cdecl, importc: "webview_run".}

proc webviewSetTitle*(w: Webview; title: cstring): cint
  {.cdecl, importc: "webview_set_title".}

proc webviewSetSize*(w: Webview; width, height: cint; hints: cint): cint
  {.cdecl, importc: "webview_set_size".}


## Loads a URL in the webview. Used for the local static server.
proc webviewNavigate*(w: Webview; url: cstring): cint
  {.cdecl, importc: "webview_navigate".}

## Installs a JavaScript snippet as a user script for every page load.
proc webviewInit*(w: Webview; js: cstring): cint
  {.cdecl, importc: "webview_init".}

## Registers `name` on `window` and routes calls to `fn`.
## `arg` is passed back unchanged; it must outlive the webview.
proc webviewBind*(w: Webview; name: cstring; fn: WebviewBindFn; arg: pointer): cint
  {.cdecl, importc: "webview_bind".}

## Evaluates JavaScript in the page. Must be called from the UI thread.
proc webviewEval*(w: Webview; js: cstring): cint
  {.cdecl, importc: "webview_eval".}

## Resolves a binding call. Status 0 means success; `result` must be valid
## JSON or an empty string for the JS `undefined` value.
proc webviewReturn*(w: Webview; id: cstring; status: cint; result: cstring): cint
  {.cdecl, importc: "webview_return".}

## Native top-level window handle (GtkWindow on Linux).
proc webviewGetWindow*(w: Webview): pointer
  {.cdecl, importc: "webview_get_window".}

## Native child handle selected by `kind`; see WebviewNativeHandleUiWidget.
proc webviewGetNativeHandle*(w: Webview; kind: cint): pointer
  {.cdecl, importc: "webview_get_native_handle".}
