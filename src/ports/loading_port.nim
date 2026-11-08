## Port for the native loading state.
##
## The application layer can dismiss the loading screen without knowing
## whether it is implemented with GTK, Win32, Cocoa, or a no-op.

type
  LoadingPort* = object
    ## Dismisses the loading state; must be safe to call more than once.
    hide*: proc() {.closure.}
