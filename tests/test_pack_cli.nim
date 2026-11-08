## Integration tests for the avelra-pack CLI.

import std/[options, os, osproc, unittest]

import adapters/archive/[payload, zip_store]
import support

let root = getTempDir() / ("avelra-pack-cli-" & $getCurrentProcessId())
let binary = root / "fake-binary"
let client = root / "client"
let output = root / "packed"
let outputResources = root / "packed-resources"
let resources = root / "resources.neu"

removeDir(root)
createDir(root)
createDir(client / "assets")
writeFile(binary, "FAKE-BINARY")
writeFile(client / "index.html", "<h1>Hello pack</h1>")
writeFile(client / "assets" / "app.js", "console.log('pack');")

proc runPack(args: string): tuple[output: string, exitCode: int] =
  execCmdEx(packPath() & " " & args)

try:
  suite "avelra-pack CLI":
    test "packs a client directory":
      let result = runPack("--binary " & binary & " --client " & client &
        " --output " & output)
      check result.exitCode == 0
      check fileExists(output)

      let footer = readPayloadFooter(output).get
      check footer.offset == uint64("FAKE-BINARY".len)
      let packed = readFile(output)
      let archive = packed[int(footer.offset) ..<
        int(footer.offset + footer.length)]
      check listZip(archive).len == 2
      check readZipEntry(archive, "index.html") ==
        some("<h1>Hello pack</h1>")
      check readZipEntry(archive, "assets/app.js") ==
        some("console.log('pack');")

    test "packs an existing resources archive":
      writeFile(resources, buildZip(@[
        ZipEntry(path: "index.html", data: "resources")
      ]))
      let result = runPack("--binary " & binary & " --resources " & resources &
        " --output " & outputResources)
      check result.exitCode == 0
      let footer = readPayloadFooter(outputResources).get
      let packed = readFile(outputResources)
      let archive = packed[int(footer.offset) ..<
        int(footer.offset + footer.length)]
      check readZipEntry(archive, "index.html") == some("resources")

    test "creates a missing output directory":
      let nested = root / "nested" / "packed"
      let result = runPack("--binary " & binary & " --client " & client &
        " --output " & nested)
      check result.exitCode == 0
      check fileExists(nested)
      removeFile(nested)

    test "does not modify the input binary":
      check readFile(binary) == "FAKE-BINARY"
      check readPayloadFooter(binary).isNone

    test "requires --force to overwrite":
      let refused = runPack("--binary " & binary & " --client " & client &
        " --output " & output)
      check refused.exitCode != 0
      let allowed = runPack("--binary " & binary & " --client " & client &
        " --output " & output & " --force")
      check allowed.exitCode == 0

    when defined(posix):
      test "output is executable on POSIX":
        check fpUserExec in getFilePermissions(output)
finally:
  removeDir(root)
