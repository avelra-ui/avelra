## Raw GTK3 / WebKitGTK declarations used by the Linux adapters.
##
## Declarations only: no loading policy, no HTML, no application logic.

type
  # Opaque GTK handles. The adapter passes them back to GTK and never
  # dereferences them, so plain pointers are sufficient.
  GtkWidget* = pointer
  GtkWindow* = pointer
  GtkOverlay* = pointer
  GtkBox* = pointer
  GtkSpinner* = pointer
  GtkLabel* = pointer
  GtkEventBox* = pointer

  GdkRGBA* = object
    red*, green*, blue*, alpha*: cdouble

  GSourceFunc* = proc(data: pointer): cint {.cdecl.}

const
  # GTK enum values used by the loading overlay.
  GtkOrientationVertical* = 1
  GtkAlignFill* = 0
  GtkAlignCenter* = 3

# Containers and layout.
proc gtkOverlayNew*(): GtkOverlay
  {.cdecl, importc: "gtk_overlay_new".}

proc gtkOverlayAddOverlay*(overlay: GtkOverlay; widget: GtkWidget)
  {.cdecl, importc: "gtk_overlay_add_overlay".}

proc gtkContainerRemove*(container: GtkWindow; widget: GtkWidget)
  {.cdecl, importc: "gtk_container_remove".}

proc gtkContainerAdd*(container: GtkWidget; widget: GtkWidget)
  {.cdecl, importc: "gtk_container_add".}

# Boxes, labels, and spinners used to build the loading state.
proc gtkBoxNew*(orientation, spacing: cint): GtkBox
  {.cdecl, importc: "gtk_box_new".}

proc gtkBoxPackStart*(box: GtkBox; child: GtkWidget;
                      expand, fill, padding: cint)
  {.cdecl, importc: "gtk_box_pack_start".}

proc gtkLabelNew*(text: cstring): GtkLabel
  {.cdecl, importc: "gtk_label_new".}

proc gtkLabelSetMarkup*(label: GtkLabel; markup: cstring)
  {.cdecl, importc: "gtk_label_set_markup".}

proc gtkSpinnerNew*(): GtkSpinner
  {.cdecl, importc: "gtk_spinner_new".}

proc gtkSpinnerStart*(spinner: GtkSpinner)
  {.cdecl, importc: "gtk_spinner_start".}

proc gtkSpinnerStop*(spinner: GtkSpinner)
  {.cdecl, importc: "gtk_spinner_stop".}

# Widget state and layout.
proc gtkEventBoxNew*(): GtkEventBox
  {.cdecl, importc: "gtk_event_box_new".}

proc gtkWidgetOverrideBackgroundColor*(widget: GtkWidget; state: cint;
                                       color: ptr GdkRGBA)
  {.cdecl, importc: "gtk_widget_override_background_color".}

proc gtkWidgetOverrideColor*(widget: GtkWidget; state: cint;
                             color: ptr GdkRGBA)
  {.cdecl, importc: "gtk_widget_override_color".}

proc gtkWidgetSetHalign*(widget: GtkWidget; align: cint)
  {.cdecl, importc: "gtk_widget_set_halign".}

proc gtkWidgetSetValign*(widget: GtkWidget; align: cint)
  {.cdecl, importc: "gtk_widget_set_valign".}

proc gtkWidgetSetHexpand*(widget: GtkWidget; expand: cint)
  {.cdecl, importc: "gtk_widget_set_hexpand".}

proc gtkWidgetSetVexpand*(widget: GtkWidget; expand: cint)
  {.cdecl, importc: "gtk_widget_set_vexpand".}

# Window-level operations.
proc gtkWidgetHide*(widget: GtkWidget)
  {.cdecl, importc: "gtk_widget_hide".}

proc gtkWidgetShowAll*(widget: GtkWidget)
  {.cdecl, importc: "gtk_widget_show_all".}

proc gtkWindowResize*(window: GtkWidget; width, height: cint)
  {.cdecl, importc: "gtk_window_resize".}

proc gtkWindowClose*(window: pointer)
  {.cdecl, importc: "gtk_window_close".}

proc gtkWindowSetIconFromFile*(window: GtkWindow; filename: cstring;
                               error: pointer): cint
  {.cdecl, importc: "gtk_window_set_icon_from_file".}

proc gtkWindowSetDefaultIconFromFile*(filename: cstring; error: pointer): cint
  {.cdecl, importc: "gtk_window_set_default_icon_from_file".}

# WebKitGTK: keep the pre-paint background in sync with the page.
proc webkitWebViewSetBackgroundColor*(view: GtkWidget; rgba: ptr GdkRGBA)
  {.cdecl, importc: "webkit_web_view_set_background_color".}

# GLib: the fallback timer that prevents an endless loading state.
proc gTimeoutAdd*(interval: cuint; fn: GSourceFunc; data: pointer): cuint
  {.cdecl, importc: "g_timeout_add".}
