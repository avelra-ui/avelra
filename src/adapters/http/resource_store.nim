## Resource sources for the static HTTP server.
##
## The server works with a store instead of touching the filesystem directly.
## `DirectoryStore` serves `client/`; `EmbeddedStore` serves a ZIP held in memory
## from a single-executable payload.

import std/[options, os, strutils]

import adapters/archive/[payload, zip_store]
import adapters/http/static_paths

const
  IndexFile* = "index.html"

type
  Resource* = object
    data*: string
    contentType*: string

  ResourceError* = enum
    notFound
    forbidden
    ioError

  ResourceResult* = object
    found*: bool
    resource*: Resource
    error*: ResourceError

  ResourceStoreKind* = enum
    directory
    embedded

  ResourceStore* = object
    kind*: ResourceStoreKind
    root*: cstring
    archive*: cstring
    archiveLen*: int

proc toOwnedCString(value: string): cstring =
  let buffer = alloc0(value.len + 1)
  if value.len > 0:
    copyMem(buffer, unsafeAddr value[0], value.len)
  cast[cstring](buffer)

proc isSafeRelativePath(path: string): bool =
  if path.len == 0:
    return true
  if path[0] == '/' or path.contains('\\') or path.contains('\0') or
      path.contains('\r') or path.contains('\n'):
    return false
  for part in path.split('/'):
    if part == ".." or part.contains(':'):
      return false
  true

proc newDirectoryStore*(root: string): ResourceStore =
  ## Creates a store rooted at an existing directory.
  if not dirExists(root):
    raise newException(OSError, "static root does not exist: " & root)
  let rootAbs = expandFilename(root)
  ResourceStore(kind: directory, root: toOwnedCString(rootAbs))

proc newEmbeddedStore*(archive: string): ResourceStore =
  ## Creates an in-memory store over a ZIP archive.
  ResourceStore(
    kind: embedded,
    archive: toOwnedCString(archive),
    archiveLen: archive.len
  )

proc openResourceStore*(executablePath, fallbackRoot: string): ResourceStore =
  ## Uses the embedded payload when present, otherwise `client/`.
  let footer = readPayloadFooter(executablePath)
  if footer.isNone:
    return newDirectoryStore(fallbackRoot)

  let info = footer.get
  let fileSize = getFileSize(executablePath)
  if fileSize < 0:
    raise newException(PayloadError, "invalid executable size")
  let size = uint64(fileSize)
  if info.offset > size or info.length > size - info.offset:
    raise newException(PayloadError, "payload is outside the executable")

  let data = readFile(executablePath)
  let start = int(info.offset)
  let finish = int(info.offset + info.length)
  let archive = data[start ..< finish]

  if crc32(archive) != info.crc:
    raise newException(PayloadError, "payload CRC mismatch")
  discard listZip(archive)
  newEmbeddedStore(archive)

proc archiveString(store: ResourceStore): string =
  ## ZIP data is binary; `$cstring` would stop at the first NUL byte.
  if store.archiveLen == 0:
    return ""
  result = newString(store.archiveLen)
  copyMem(addr result[0], store.archive, store.archiveLen)

proc close*(store: var ResourceStore) =
  ## Releases owned paths and archive data. Safe to call twice.
  if store.root != nil:
    dealloc(cast[pointer](store.root))
    store.root = nil
  if store.archive != nil:
    dealloc(cast[pointer](store.archive))
    store.archive = nil
    store.archiveLen = 0

proc get*(store: ResourceStore; path: string): ResourceResult =
  ## Returns a resource for a path relative to the store root.
  if not isSafeRelativePath(path):
    return ResourceResult(found: false, error: forbidden)

  case store.kind
  of directory:
    if store.root == nil:
      return ResourceResult(found: false, error: forbidden)

    let root = $store.root
    let candidate = resolvePath(root, path)
    if candidate.len == 0:
      return ResourceResult(found: false, error: forbidden)

    var filePath = candidate
    if dirExists(filePath):
      filePath = filePath / IndexFile

    if not fileExists(filePath):
      return ResourceResult(found: false, error: notFound)

    try:
      let canonical = expandFilename(filePath)
      if not containsPath(root, canonical):
        return ResourceResult(found: false, error: forbidden)
    except OSError:
      return ResourceResult(found: false, error: forbidden)

    var data: string
    try:
      data = readFile(filePath)
    except CatchableError:
      return ResourceResult(found: false, error: ioError)

    ResourceResult(
      found: true,
      resource: Resource(data: data, contentType: contentType(filePath))
    )
  of embedded:
    if store.archive == nil or store.archiveLen == 0:
      return ResourceResult(found: false, error: forbidden)

    try:
      let zip = archiveString(store)
      var entryPath = if path.len == 0: IndexFile else: path
      var entry = readZipEntry(zip, entryPath)
      if entry.isNone and splitFile(entryPath).ext.len == 0:
        entryPath = entryPath & "/" & IndexFile
        entry = readZipEntry(zip, entryPath)
      if entry.isNone:
        return ResourceResult(found: false, error: notFound)
      ResourceResult(
        found: true,
        resource: Resource(data: entry.get, contentType: contentType(entryPath))
      )
    except CatchableError:
      return ResourceResult(found: false, error: ioError)
