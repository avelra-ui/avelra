## User-facing Avelra CLI. Internal tools live in libexec.

import std/[json, os, osproc, strutils]

import cli/[config, layout, project, runtime_deps]
import avelra_version

type
  CliOptions = object
    configPath: string
    command: string
    arguments: seq[string]

  BuildResult = object
    appDir: string
    binary: string
    hasExtensions: bool

proc usage() =
  echo "Usage: avelra [--config <path>] <command> [options]"
  echo ""
  echo "Commands:"
  echo "  init <dir>                 create a new desktop project"
  echo "  run                        run the dev runtime"
  echo "  build                      build a single executable"
  echo "  installer --target <name>  build an app installer (tar/deb/appimage)"
  echo "  doctor                     check Linux runtime dependencies"
  echo ""
  echo "Internal tools: avelra-runtime, avelra-pack, avelra-installer"

proc parseArgs(): CliOptions =
  result.configPath = "avelra.config.json"
  let args = commandLineParams()
  var index = 0
  while index < args.len:
    let argument = args[index]
    case argument
    of "--help", "-h":
      usage()
      quit(0)
    of "--version":
      echo "avelra " & AvelraVersion
      quit(0)
    of "--config":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--config requires a path")
      result.configPath = args[index]
    else:
      if result.command.len == 0:
        result.command = argument
      else:
        result.arguments.add argument
    inc index

proc requireConfig(path: string): AppConfig =
  loadConfig(path)

proc buildApp(configPath: string): BuildResult =
  let config = requireConfig(configPath)
  let project = projectDir(configPath)
  let client = clientDir(configPath, config)
  if not dirExists(client):
    raise newException(IOError, "client directory not found: " & client)
  let runtime = toolPath("avelra-runtime")
  let packer = toolPath("avelra-pack")
  let slug = slugify(config.name)
  let outputDir = project / "dist" / slug
  let hasExtensions = config.extensions.len > 0

  if hasExtensions:
    removeDir(outputDir)
    createDir(outputDir / "bin")
    let sourceExtensions = project / "extensions"
    if not dirExists(sourceExtensions):
      raise newException(IOError,
        "extensions directory not found: " & sourceExtensions)

  createDir(outputDir)
  let output = if hasExtensions: outputDir / "bin" / slug
               else: outputDir / slug
  let command = quoteShellCommand([
    packer,
    "--binary", runtime,
    "--client", client,
    "--config", configPath,
    "--output", output,
    "--force"
  ])
  let packResult = execCmdEx(command)
  if packResult.output.len > 0:
    stdout.write(packResult.output)
  if packResult.exitCode != 0:
    raise newException(OSError, "packer failed with exit code " & $packResult.exitCode)

  if hasExtensions:
    var builtConfig = parseFile(configPath)
    if config.icon.len > 0:
      let sourceIcon = if isAbsolute(config.icon): config.icon
                       else: project / config.icon
      if not fileExists(sourceIcon):
        raise newException(IOError, "icon not found: " & sourceIcon)
      let iconName = lastPathPart(sourceIcon)
      copyFile(sourceIcon, outputDir / iconName)
      builtConfig["icon"] = %iconName
    writeFile(outputDir / "avelra.config.json",
      builtConfig.pretty & "\n")
    # Copy only the executable of each configured extension. Never ship
    # extension sources, tests or local build artifacts from extensions/.
    for extension in config.extensions:
      let command = commandFor(extension)
      let executable = command[0]
      if not (executable.contains({'/', '\\'}) or executable.startsWith(".")):
        continue
      if isAbsolute(executable):
        raise newException(ValueError,
          "extension executable must be relative for app output: " & executable)
      let source = project / executable
      let destination = outputDir / executable
      if not fileExists(source):
        raise newException(IOError,
          "extension executable not found: " & source)
      createDir(parentDir(destination))
      copyFile(source, destination)
      setFilePermissions(destination, getFilePermissions(source))

  echo "built ", output
  result = BuildResult(
    appDir: outputDir,
    binary: output,
    hasExtensions: hasExtensions
  )

proc installerApp(configPath, target, output: string): string =
  if target notin ["tar", "tar.gz", "deb", "appimage"]:
    raise newException(ValueError, "unsupported target: " & target)
  let build = buildApp(configPath)
  let installer = toolPath("avelra-installer")
  var arguments = @[installer]
  if build.hasExtensions:
    arguments.add "--app-dir"
    arguments.add build.appDir
  else:
    arguments.add "--binary"
    arguments.add build.binary
    arguments.add "--config"
    arguments.add configPath
  arguments.add "--target"
  arguments.add target
  if output.len > 0:
    arguments.add "--output"
    arguments.add output
  let installResult = execCmdEx(quoteShellCommand(arguments))
  if installResult.output.len > 0:
    stdout.write(installResult.output)
  if installResult.exitCode != 0:
    raise newException(OSError, "installer failed with exit code " &
      $installResult.exitCode)
  build.binary

proc runApp(configPath: string): int =
  if not runtimePreflight():
    return 2
  let config = requireConfig(configPath)
  let client = clientDir(configPath, config)
  if not dirExists(client):
    raise newException(IOError, "client directory not found: " & client)
  let runtime = toolPath("avelra-runtime")
  var arguments = @[
    "--client", client,
    "--config", absolutePath(configPath),
    "--title", config.window.title,
    "--width", $config.window.width,
    "--height", $config.window.height
  ]
  if config.icon.len > 0:
    arguments.add "--icon"
    arguments.add(if isAbsolute(config.icon): config.icon
                  else: projectDir(configPath) / config.icon)

  let process = startProcess(
    runtime,
    args = arguments,
    options = {poParentStreams}
  )
  result = process.waitForExit()
  process.close()

proc main(): int =
  let options = parseArgs()
  if options.command.len == 0:
    usage()
    return 0

  case options.command
  of "init":
    var destination = ""
    var force = false
    for argument in options.arguments:
      if argument == "--force":
        force = true
      elif destination.len == 0:
        destination = argument
      else:
        raise newException(ValueError, "init accepts exactly one directory")
    if destination.len == 0:
      raise newException(ValueError, "init requires a directory")
    let configPath = initProject(destination, templateDir(), force)
    echo "created ", destination
    echo "config: ", configPath
    return 0
  of "run":
    if options.arguments.len > 0:
      raise newException(ValueError, "run takes no arguments")
    return runApp(options.configPath)
  of "doctor":
    if options.arguments.len > 0:
      raise newException(ValueError, "doctor takes no arguments")
    when defined(linux):
      let checks = diagnose(linuxRuntimeSpecs())
      printDoctor(checks)
      return if failures(checks) == 0: 0 else: 1
    else:
      echo "Avelra runtime dependencies: no extra checks on this platform"
      return 0
  of "build":
    if options.arguments.len > 0:
      raise newException(ValueError, "build takes no arguments")
    discard buildApp(options.configPath)
    return 0
  of "installer":
    var target = ""
    var output = ""
    var index = 0
    while index < options.arguments.len:
      case options.arguments[index]
      of "--target":
        inc index
        if index >= options.arguments.len:
          raise newException(ValueError, "--target requires a value")
        target = options.arguments[index]
      of "--output":
        inc index
        if index >= options.arguments.len:
          raise newException(ValueError, "--output requires a path")
        output = options.arguments[index]
      else:
        raise newException(ValueError, "unknown installer option: " &
          options.arguments[index])
      inc index
    if target.len == 0:
      raise newException(ValueError, "installer requires --target")
    discard installerApp(options.configPath, target, output)
    return 0
  else:
    raise newException(ValueError, "unknown command: " & options.command)

when isMainModule:
  try:
    quit(main())
  except CatchableError as exc:
    stderr.writeLine("avelra: " & exc.msg)
    quit(1)
