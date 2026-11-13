## Port for opening URLs in the user's system browser.
##
## The application layer depends on this abstraction. Platform-specific
## process launching lives in `adapters/system/url_open.nim`.

type
  UrlOpenPort* = object
    ## Opens an http(s) URL in the default browser.
    ## Returns false when the handler is unavailable or exits unsuccessfully.
    openUrl*: proc(url: string): bool {.closure.}
