## URL policy for the public `os.openUrl` surface.
##
## Parsing is delegated to std/uri; this module owns the security allowlist.

import std/[strutils, uri]

proc hasControlChars(value: string): bool =
  for ch in value:
    let code = ord(ch)
    if code < 0x20 or code == 0x7F:
      return true

proc isAllowedUrl*(url: string): bool =
  ## Allows web and mail URLs only; custom and file-like schemes stay out.
  if url.len == 0 or url != url.strip() or hasControlChars(url):
    return false

  var parsed: Uri
  try:
    parseUri(url, parsed)
  except CatchableError:
    return false

  case parsed.scheme.toLowerAscii
  of "http", "https":
    result = parsed.hostname.len > 0
  of "mailto":
    # parseUri stores `user@host` as username/hostname for mailto URLs.
    result = parsed.username.len > 0 and parsed.hostname.len > 0
  else:
    result = false
