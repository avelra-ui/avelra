## Project initialization and template copying.

import std/[os]

import cli/config

proc isEmptyDir(path: string): bool =
  for _ in walkDir(path):
    return false
  true

proc initProject*(destination, templatePath: string; force = false): string =
  ## Creates a project from a template and returns the config path.
  let target = absolutePath(destination)
  if fileExists(target):
    raise newException(IOError, "destination is a file: " & target)
  if dirExists(target):
    if not isEmptyDir(target) and not force:
      raise newException(IOError, "destination is not empty: " & target)
    removeDir(target)

  if not dirExists(templatePath):
    raise newException(IOError, "template not found: " & templatePath)

  createDir(target)
  copyDir(templatePath, target)

  let configPath = target / "avelra.config.json"
  var config = loadConfig(configPath)
  config.name = lastPathPart(target)
  if config.name.len == 0:
    config.name = "my-app"
  config.identifier = "com.example." & slugify(config.name)
  config.window.title = config.name
  saveConfig(configPath, config)
  configPath
