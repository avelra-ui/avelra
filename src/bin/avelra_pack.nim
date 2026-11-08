## avelra-pack: post-build single-executable packer.
##
## Takes an already built binary and either a client directory or a prepared
## ZIP archive; appends the archive and footer. Nim is not invoked.

import std/[os, strutils]

import adapters/archive/packaging

const
  Version = "1"

type
  Options = object
    binary: string
    client: string
    resources: string
    config: string
    output: string
    force: bool

proc usage() =
  echo "Usage:"
  echo "  avelra-pack --binary <path> --client <dir> --config <json> --output <path> [--force]"
  echo "  avelra-pack --binary <path> --resources <zip> --output <path> [--force]"
  echo ""
  echo "The binary is not recompiled. The output is binary + ZIP + footer."

proc valueAfter(args: seq[string]; index: var int; argument: string): string =
  let separator = argument.find('=')
  if separator >= 0:
    return argument[separator + 1 .. ^1]
  inc index
  if index >= args.len:
    raise newException(ValueError, "missing value for " & argument)
  args[index]

proc parseOptions(): Options =
  let args = commandLineParams()
  var index = 0
  while index < args.len:
    let argument = args[index]
    case argument
    of "--help", "-h":
      usage()
      quit(0)
    of "--version":
      echo "avelra-pack " & Version
      quit(0)
    of "--force":
      result.force = true
    of "--binary":
      result.binary = valueAfter(args, index, argument)
    of "--client":
      result.client = valueAfter(args, index, argument)
    of "--resources":
      result.resources = valueAfter(args, index, argument)
    of "--config":
      result.config = valueAfter(args, index, argument)
    of "--output":
      result.output = valueAfter(args, index, argument)
    else:
      if argument.startsWith("--binary="):
        result.binary = argument["--binary=".len .. ^1]
      elif argument.startsWith("--client="):
        result.client = argument["--client=".len .. ^1]
      elif argument.startsWith("--resources="):
        result.resources = argument["--resources=".len .. ^1]
      elif argument.startsWith("--config="):
        result.config = argument["--config=".len .. ^1]
      elif argument.startsWith("--output="):
        result.output = argument["--output=".len .. ^1]
      else:
        raise newException(ValueError, "unknown argument: " & argument)
    inc index

proc main() =
  let options = parseOptions()
  if options.binary.len == 0:
    raise newException(ValueError, "--binary is required")
  if options.output.len == 0:
    raise newException(ValueError, "--output is required")
  if (options.client.len > 0) == (options.resources.len > 0):
    raise newException(ValueError, "use exactly one of --client or --resources")
  if options.resources.len > 0 and options.config.len > 0:
    raise newException(ValueError, "--config is supported with --client")

  if absolutePath(options.binary) == absolutePath(options.output):
    raise newException(ValueError, "output must differ from the input binary")

  if options.client.len > 0:
    packClientDirectory(options.binary, options.client, options.output,
                        options.config, options.force)
  else:
    packResourcesArchive(options.binary, options.resources, options.output,
                         options.force)

  echo "packed ", options.output, " (", getFileSize(options.output), " bytes)"

when isMainModule:
  try:
    main()
  except CatchableError as exc:
    stderr.writeLine("avelra-pack: " & exc.msg)
    quit(1)
