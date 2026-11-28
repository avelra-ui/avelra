## Package payload layout test (uses a fake SDK prefix).

import std/[os, osproc, strutils, unittest]

let root = getTempDir() / ("avelra-package-" & $getCurrentProcessId())
let oldSource = getEnv("AVELRA_SDK_SOURCE")
let buildDir = root / "build"
let binDir = buildDir / "bin"
let libexecDir = buildDir / "libexec" / "avelra"
let shareDir = buildDir / "share" / "avelra" / "templates" / "app"

removeDir(root)
createDir(binDir)
createDir(libexecDir)
createDir(shareDir / "client")
writeFile(binDir / "avelra", """#!/bin/sh
echo "avelra 9.9.9"
""")
for file in ["avelra-runtime", "avelra-pack", "avelra-installer"]:
  writeFile(libexecDir / file, "")
writeFile(root / "README.md", "SDK readme")
writeFile(shareDir / "avelra.config.json", "{}")
writeFile(shareDir / "client" / "index.html", "sdk")
for file in [binDir / "avelra", libexecDir / "avelra-runtime",
             libexecDir / "avelra-pack", libexecDir / "avelra-installer"]:
  setFilePermissions(file, {fpUserRead, fpUserWrite, fpUserExec})
putEnv("AVELRA_SDK_SOURCE", root)

try:
  suite "package payload":
    test "tar contains bin, libexec and templates":
      let result = execCmdEx("./scripts/package/sdk.sh --tar")
      check result.exitCode == 0
      let archive = buildDir / "packages" / "avelra-9.9.9-linux-x64.tar.gz"
      check fileExists(archive)
      let listing = execCmdEx("tar -tzf " & archive).output
      check listing.contains("bin/avelra")
      check listing.contains("libexec/avelra/avelra-runtime")
      check listing.contains("libexec/avelra/avelra-pack")
      check listing.contains("libexec/avelra/avelra-installer")
      check listing.contains("share/avelra/templates/app/client/index.html")
      check listing.contains("share/doc/avelra/README.md")
finally:
  if oldSource.len > 0: putEnv("AVELRA_SDK_SOURCE", oldSource)
  else: delEnv("AVELRA_SDK_SOURCE")
  removeDir(root)
