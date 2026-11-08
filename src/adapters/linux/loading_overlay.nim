## Native GTK loading overlay.
##
## The GTK window is shown immediately. While WebKit starts its web process,
## this opaque layer covers the WebView with a branded background, a spinner,
## and a status label. It is removed when the application reports `app.ready`
## (or by a 3-second fallback).

import adapters/linux/gtk_api
import ports/loading_port

const LoadingTimeoutMs = 3000

type
  LoadingOverlay* = ref object
    ## Identifies the opaque cover and its spinner. Kept alive by the loading
    ## port closure and by AppWindow; the fallback timer holds only a raw pointer.
    cover: GtkWidget
    spinner: GtkSpinner

proc hide*(overlay: LoadingOverlay) =
  ## Hides the overlay and stops the spinner. Safe to call repeatedly, including
  ## after the fallback timer fired.
  if overlay == nil:
    return

  if overlay.spinner != nil:
    gtkSpinnerStop(overlay.spinner)
    overlay.spinner = nil

  if overlay.cover != nil:
    gtkWidgetHide(overlay.cover)
    overlay.cover = nil

proc onLoadingTimeout(data: pointer): cint {.cdecl.} =
  ## Last-resort guard: never leave the user on a spinner if app.ready is lost.
  hide(cast[LoadingOverlay](data))
  return 0

proc installLoadingOverlay*(gtkWindow, webviewWidget: pointer): LoadingOverlay =
  ## Reparents the WebView into a GtkOverlay, adds an opaque loading cover, and
  ## schedules the fallback. Returns nil when native handles are unavailable.
  if gtkWindow == nil or webviewWidget == nil:
    return nil

  # Match the page background; the WebView is white before the first paint.
  var background = GdkRGBA(
    red: 246.0 / 255.0,
    green: 247.0 / 255.0,
    blue: 249.0 / 255.0,
    alpha: 1.0
  )
  webkitWebViewSetBackgroundColor(cast[GtkWidget](webviewWidget), addr background)

  # Reparent the WebView into a GtkOverlay so the loading state can sit on top.
  gtkContainerRemove(cast[GtkWindow](gtkWindow),
                     cast[GtkWidget](webviewWidget))

  let overlay = gtkOverlayNew()
  gtkContainerAdd(cast[GtkWidget](overlay), cast[GtkWidget](webviewWidget))

  let box = gtkBoxNew(cint(GtkOrientationVertical), cint(10))
  gtkWidgetSetHalign(cast[GtkWidget](box), cint(GtkAlignCenter))
  gtkWidgetSetValign(cast[GtkWidget](box), cint(GtkAlignCenter))
  gtkWidgetSetHexpand(cast[GtkWidget](box), 1)
  gtkWidgetSetVexpand(cast[GtkWidget](box), 1)

  let spinner = gtkSpinnerNew()
  gtkWidgetSetHalign(cast[GtkWidget](spinner), cint(GtkAlignCenter))
  var accent = GdkRGBA(
    red: 37.0 / 255.0,
    green: 99.0 / 255.0,
    blue: 235.0 / 255.0,
    alpha: 1.0
  )
  gtkWidgetOverrideColor(cast[GtkWidget](spinner), 0, addr accent)
  gtkSpinnerStart(spinner)
  gtkBoxPackStart(box, cast[GtkWidget](spinner), 0, 0, 0)

  let label = gtkLabelNew(nil)
  gtkLabelSetMarkup(label,
    "<span foreground='#1f2937' size='x-large' weight='bold'>Avelra</span>\n" &
    "<span foreground='#6b7280'>Starting WebView…</span>")
  gtkWidgetSetHalign(cast[GtkWidget](label), cint(GtkAlignCenter))
  gtkBoxPackStart(box, cast[GtkWidget](label), 0, 0, 0)

  # GtkEventBox has its own window, so it paints an opaque background over the
  # WebView while the page is loading.
  let cover = gtkEventBoxNew()
  gtkWidgetSetHalign(cast[GtkWidget](cover), cint(GtkAlignFill))
  gtkWidgetSetValign(cast[GtkWidget](cover), cint(GtkAlignFill))
  gtkWidgetSetHexpand(cast[GtkWidget](cover), 1)
  gtkWidgetSetVexpand(cast[GtkWidget](cover), 1)
  gtkWidgetOverrideBackgroundColor(cast[GtkWidget](cover), 0, addr background)

  gtkContainerAdd(cast[GtkWidget](cover), cast[GtkWidget](box))
  gtkOverlayAddOverlay(overlay, cast[GtkWidget](cover))
  gtkContainerAdd(cast[GtkWidget](gtkWindow), cast[GtkWidget](overlay))
  gtkWidgetShowAll(cast[GtkWidget](overlay))

  result = LoadingOverlay(
    cover: cast[GtkWidget](cover),
    spinner: spinner
  )
  discard gTimeoutAdd(cuint(LoadingTimeoutMs), onLoadingTimeout,
                      cast[pointer](result))

proc toLoadingPort*(overlay: LoadingOverlay): LoadingPort =
  ## Adapts the GTK overlay to the application-level port. A nil overlay maps
  ## to a no-op so the application layer never needs platform checks.
  if overlay == nil:
    return LoadingPort(hide: proc() = discard)
  LoadingPort(hide: proc() = overlay.hide())
