## Locates the user-facing CLI and its internal binaries/templates.

import std/[os]

proc executableName*(name: string): string =
  when defined(windows):
    name & ".exe"
  else:
    name

proc resolveHome*(exeDir: string): string =
  ## Resolves portable (`bin/` next to `libexec/`) and installed layouts.
  if dirExists(exeDir / "libexec" / "avelra"):
    return parentDir(exeDir)
  if lastPathPart(exeDir) == "bin":
    let prefix = parentDir(exeDir)
    if prefix != exeDir and dirExists(prefix / "libexec" / "avelra"):
      return prefix
  exeDir

proc avelraHome*(): string =
  ## Installed root, dev root, or `AVELRA_HOME`.
  let override = getEnv("AVELRA_HOME")
  if override.len > 0:
    return absolutePath(override)
  resolveHome(getAppDir())

proc toolPath*(name: string): string =
  let home = avelraHome()
  let installed = home / "libexec" / "avelra" / executableName(name)
  if fileExists(installed):
    return installed
  let dev = home / executableName(name)
  if fileExists(dev):
    return dev
  raise newException(IOError, "tool not found: " & name)

proc templateDir*(): string =
  let home = avelraHome()
  for candidate in [
    home / "share" / "avelra" / "templates" / "app",
    home / "templates" / "app"
  ]:
    if dirExists(candidate):
      return candidate
  raise newException(IOError, "application template not found")
