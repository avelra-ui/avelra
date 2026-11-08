## Internal Linux installer builder for user applications.

import std/[os]

import installer/linux

proc usage() =
  echo "Usage: avelra-installer --app-dir <dir> --target <tar|deb|appimage> [--output <path>]"
  echo "   or: avelra-installer --binary <path> --config <path> " &
    "--target <tar|deb|appimage> [--output <path>]"

proc main(): int =
  var binary = ""
  var appDir = ""
  var configPath = ""
  var target = ""
  var output = ""
  let args = commandLineParams()
  var index = 0
  while index < args.len:
    case args[index]
    of "--binary":
      inc index
      if index >= args.len: raise newException(ValueError, "--binary requires a path")
      binary = args[index]
    of "--app-dir":
      inc index
      if index >= args.len: raise newException(ValueError, "--app-dir requires a path")
      appDir = args[index]
    of "--config":
      inc index
      if index >= args.len: raise newException(ValueError, "--config requires a path")
      configPath = args[index]
    of "--target":
      inc index
      if index >= args.len: raise newException(ValueError, "--target requires a value")
      target = args[index]
    of "--output":
      inc index
      if index >= args.len: raise newException(ValueError, "--output requires a path")
      output = args[index]
    of "--help", "-h":
      usage()
      return 0
    else:
      raise newException(ValueError, "unknown option: " & args[index])
    inc index
  if target.len == 0:
    raise newException(ValueError, "target is required")

  let parsedTarget = parseInstallerTarget(target)
  if appDir.len > 0:
    if binary.len > 0 or configPath.len > 0:
      raise newException(ValueError,
        "--app-dir cannot be combined with --binary/--config")
    discard buildAppInstaller(appDir, parsedTarget, output)
  else:
    if binary.len == 0 or configPath.len == 0:
      raise newException(ValueError,
        "binary and config are required without --app-dir")
    discard buildInstaller(binary, configPath, parsedTarget, output)
  return 0

when isMainModule:
  try:
    quit(main())
  except CatchableError as exc:
    stderr.writeLine("avelra-installer: " & exc.msg)
    quit(1)
