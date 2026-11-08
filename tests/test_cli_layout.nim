## CLI layout/tool discovery tests.

import std/[os, unittest]

import cli/layout

let root = getTempDir() / ("avelra-cli-layout-" & $getCurrentProcessId())
let oldHome = getEnv("AVELRA_HOME")
removeDir(root)
createDir(root / "libexec" / "avelra")
createDir(root / "share" / "avelra" / "templates" / "app")
writeFile(root / "libexec" / "avelra" / executableName("avelra-runtime"), "")
writeFile(root / "share" / "avelra" / "templates" / "app" / "index.html", "template")
putEnv("AVELRA_HOME", root)

try:
  suite "CLI layout":
    test "AVELRA_HOME overrides the install root":
      check avelraHome() == root
      check toolPath("avelra-runtime") ==
        root / "libexec" / "avelra" / executableName("avelra-runtime")

    test "templateDir finds share templates":
      check templateDir() == root / "share" / "avelra" / "templates" / "app"

    test "resolveHome handles the SDK bin/ layout":
      let prefix = root / "prefix"
      createDir(prefix / "bin")
      createDir(prefix / "libexec" / "avelra")
      check resolveHome(prefix / "bin") == prefix

    test "missing tools are reported":
      expect IOError:
        discard toolPath("missing-tool")
finally:
  if oldHome.len > 0:
    putEnv("AVELRA_HOME", oldHome)
  else:
    delEnv("AVELRA_HOME")
  removeDir(root)
