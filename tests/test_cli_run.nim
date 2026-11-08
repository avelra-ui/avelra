## CLI run dispatch without a GUI.

import std/[os, osproc, strutils, unittest]

import support

let root = getTempDir() / ("avelra-cli-run-" & $getCurrentProcessId())
let oldHome = getEnv("AVELRA_HOME")
let oldArgs = getEnv("AVELRA_FAKE_ARGS")
removeDir(root)
createDir(root / "libexec" / "avelra")
createDir(root / "client")
writeFile(root / "client" / "index.html", "test")
writeFile(root / "avelra.config.json", """{
  "name":"Run Test",
  "client":"client",
  "window":{"title":"Run Test","width":640,"height":480}
}""")
let fake = root / "libexec" / "avelra" / "avelra-runtime"
writeFile(fake, """#!/bin/sh
printf '%s\n' "$@" > "$AVELRA_FAKE_ARGS"
exit 7
""")
setFilePermissions(fake, {fpUserRead, fpUserWrite, fpUserExec})
putEnv("AVELRA_HOME", root)
putEnv("AVELRA_FAKE_ARGS", root / "args.txt")

try:
  suite "CLI run":
    test "passes config values and returns runtime code":
      let result = execCmdEx(cliPath() & " --config " &
        (root / "avelra.config.json") & " run")
      check result.exitCode == 7

    test "runtime receives client and window options":
      let args = readFile(root / "args.txt")
      check args.contains("--client")
      check args.contains(root / "client")
      check args.contains("--title")
      check args.contains("Run Test")
      check args.contains("640")
      check args.contains("480")
finally:
  if oldHome.len > 0: putEnv("AVELRA_HOME", oldHome)
  else: delEnv("AVELRA_HOME")
  if oldArgs.len > 0: putEnv("AVELRA_FAKE_ARGS", oldArgs)
  else: delEnv("AVELRA_FAKE_ARGS")
  removeDir(root)
