## Canonical cross-platform test entrypoint.
##
## Linux delegates to the existing full platform suite. Windows and macOS x64
## run the shared core suite plus the package contract against release outputs.

import std/[os, osproc, sequtils, strutils]

const root = currentSourcePath().parentDir.parentDir
const exe = when defined(windows): ".exe" else: ""

let buildDir = root / "build"
let testBin = buildDir / "tests" / "bin"
let nimcache = buildDir / "tests" / "nimcache-core"

proc run(command: string; args: seq[string]): int =
  let cmd = quoteShell(command) & " " & args.mapIt(quoteShell(it)).join(" ")
  echo "::group::", cmd
  let (output, code) = execCmdEx(cmd)
  echo output
  echo "::endgroup::"
  result = code

proc compileTest(name: string; source = "") =
  let sourcePath = if source.len > 0: source else: "tests/" & name & ".nim"
  let code = run("nim", @[
    "c", "--hints:off", "--mm:orc", "--threads:on",
    "--path:src", "--path:tests",
    "--nimcache:" & nimcache,
    "--out:" & (testBin / (name & exe)),
    sourcePath])
  if code != 0:
    raise newException(OSError, "compile failed: " & name)

proc runTest(name: string) =
  compileTest(name)
  let code = run(testBin / (name & exe), @[])
  if code != 0:
    raise newException(OSError, "test failed: " & name)

proc coreSuite() =
  for name in [
    "test_native_call", "test_dispatcher", "test_url_policy",
    "test_static_paths", "test_resource_store", "test_zip", "test_payload",
    "test_embedded_store", "test_bind_error", "test_platform_checks",
    "test_cli_config", "test_cli_help", "test_cli_layout",
    "test_cli_init", "test_cli_build", "test_cli_run",
    "test_extension_config"]:
    runTest(name)

when defined(linux):
  quit(run("bash", @["tests/run_tests.sh"]))
else:
  createDir(testBin)
  createDir(nimcache)
  putEnv("AVELRA_CLI", buildDir / "bin" / ("avelra" & exe))
  putEnv("AVELRA_PACK", buildDir / "libexec" / "avelra" / ("avelra-pack" & exe))
  putEnv("AVELRA_TEST_BIN", testBin)
  compileTest("fake_runtime", "tests/fixtures/fake_runtime.nim")
  compileTest("extension_echo", "tests/fixtures/extension_echo.nim")
  compileTest("single_exe_harness", "tests/single_exe_harness.nim")
  coreSuite()
  runTest("test_package_contract")
  runTest("test_installer_platform")
