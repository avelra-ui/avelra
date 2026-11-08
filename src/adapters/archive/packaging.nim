## Packaging helpers for the post-build single-executable.

import std/[algorithm, json, options, os, strutils]

import adapters/archive/[payload, zip_store]

proc collectClientEntries*(root, configPath: string): seq[ZipEntry] =
  ## Collects regular files under `client/` into deterministic ZIP entries.
  ## The app config is stored as an internal metadata entry.
  if not dirExists(root):
    raise newException(OSError, "client directory does not exist: " & root)
  if configPath.len > 0 and not fileExists(configPath):
    raise newException(OSError, "config file does not exist: " & configPath)

  for path in walkDirRec(root, yieldFilter = {pcFile}):
    let relative = relativePath(path, root).replace(DirSep, '/')
    validateEntryPath(relative)
    result.add ZipEntry(path: relative, data: readFile(path))

  if configPath.len > 0:
    result.add ZipEntry(path: ".avelra/config.json", data: readFile(configPath))
    let config = parseFile(configPath)
    if config.hasKey("icon") and config["icon"].kind == JString:
      let icon = config["icon"].getStr()
      if icon.len > 0:
        let iconPath = if isAbsolute(icon): icon
                       else: parentDir(absolutePath(configPath)) / icon
        if not fileExists(iconPath):
          raise newException(OSError, "icon file does not exist: " & iconPath)
        result.add ZipEntry(path: ".avelra/icon.png", data: readFile(iconPath))

  result.sort(proc(left, right: ZipEntry): int = cmp(left.path, right.path))

proc writePackedExecutable*(binary, archive, output: string; force = false) =
  ## Writes binary + ZIP + footer atomically, then makes it executable.
  if fileExists(output) and not force:
    raise newException(OSError, "output already exists: " & output)

  let outputDir = parentDir(output)
  if outputDir.len > 0 and not dirExists(outputDir):
    createDir(outputDir)

  let temporary = output & ".tmp-" & $getCurrentProcessId()
  try:
    writeFile(temporary, appendPayload(binary, archive))
    when defined(posix):
      setFilePermissions(temporary, {
        fpUserRead, fpUserWrite, fpUserExec,
        fpGroupRead, fpGroupExec,
        fpOthersRead, fpOthersExec
      })
    if fileExists(output):
      removeFile(output)
    moveFile(temporary, output)
  except CatchableError:
    if fileExists(temporary):
      removeFile(temporary)
    raise

proc packClientDirectory*(binaryPath, clientDir, output: string;
                          configPath = ""; force = false) =
  ## Packs a directory of client files and its app config into a single
  ## executable.
  let binary = readFile(binaryPath)
  if readPayloadFooter(binaryPath).isSome:
    raise newException(OSError, "binary already contains a payload: " & binaryPath)
  let archive = buildZip(collectClientEntries(clientDir, configPath))
  writePackedExecutable(binary, archive, output, force)

proc packResourcesArchive*(binaryPath, archivePath, output: string;
                           force = false) =
  ## Packs an existing ZIP archive into a single executable.
  let binary = readFile(binaryPath)
  if readPayloadFooter(binaryPath).isSome:
    raise newException(OSError, "binary already contains a payload: " & binaryPath)
  let archive = readFile(archivePath)
  discard listZip(archive)
  writePackedExecutable(binary, archive, output, force)
