## Pure path and MIME helpers for the local static server.
##
## This module has no sockets or threads, so its rules are unit-testable.

import std/[mimetypes, os, strutils, uri]

type
  ParsedPath* = object
    valid*: bool
    relative*: string

proc parseRequestPath*(target: string): ParsedPath =
  ## Decodes an HTTP request target into a safe path relative to the root.
  ## Returns `valid = false` for absolute URLs, traversal, NUL, backslashes,
  ## Windows drive letters, and control characters.
  var raw = target
  let query = raw.find('?')
  if query >= 0:
    raw = raw[0 ..< query]

  if raw.len == 0 or raw[0] != '/':
    return

  let decoded = decodeUrl(raw, decodePlus = false)
  if decoded.contains('\0') or decoded.contains('\\') or
      decoded.contains('\r') or decoded.contains('\n'):
    return

  var parts: seq[string]
  for part in decoded.split('/'):
    if part.len == 0 or part == ".":
      continue
    if part == ".." or part.contains(':'):
      return
    parts.add part

  ParsedPath(valid: true, relative: parts.join("/"))

proc resolvePath*(root, relative: string): string =
  ## Joins a safe relative path with the root and verifies containment.
  let rootAbs = normalizedPath(absolutePath(root))
  var candidate = rootAbs
  if relative.len > 0:
    candidate = normalizedPath(rootAbs / relative)

  if candidate != rootAbs and not candidate.startsWith(rootAbs & $DirSep):
    return ""
  candidate

proc containsPath*(root, candidate: string): bool =
  ## Checks a canonical candidate path against a canonical root.
  let rootAbs = normalizedPath(absolutePath(root))
  let candidateAbs = normalizedPath(absolutePath(candidate))
  candidateAbs == rootAbs or candidateAbs.startsWith(rootAbs & $DirSep)

proc isSpaFallback*(relative, accept: string): bool =
  ## Extension-less routes fall back to index.html for HTML clients.
  if relative.len == 0:
    return true
  if splitFile(relative).ext.len > 0:
    return false
  accept.toLowerAscii().contains("text/html")

proc contentType*(path: string): string =
  ## Returns a MIME type for a file path, defaulting to octet-stream.
  ## A per-call database keeps the helper GC-safe for worker threads.
  let ext = splitFile(path).ext
  if ext.len == 0:
    return "application/octet-stream"
  let mimeDb = newMimetypes()
  mimeDb.getMimetype(ext, "application/octet-stream")
