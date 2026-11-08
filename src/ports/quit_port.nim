## Port for a clean application exit.

type
  QuitPort* = object
    ## Closes the application window from the UI thread.
    quit*: proc() {.closure.}
