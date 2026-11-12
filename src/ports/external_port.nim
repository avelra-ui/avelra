## Port for opening URLs in the system handler.
##
## The application layer depends on this abstraction. Platform-specific
## process launching lives in `adapters/system/external.nim`.

type
  ExternalPort* = object
    ## Opens an http(s) URL in the user's default browser.
    ## Returns false when the platform cannot start a handler.
    open*: proc(url: string): bool {.closure.}
