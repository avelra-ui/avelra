## Canonical cross-platform test entrypoint.
##
## All platforms run the shared core suite. Linux adds the Linux-specific
## installer/SDK/release implementations; Windows and macOS x64 add platform
## package, installer and release-tree contracts against assembled outputs.

import std/[os, osproc, sequtils, strutils]

const root = currentSourcePath().parentDir.parentDir
const exe = when defined(windows): ".exe" else: ""

let buildDir = root / "build"
let testBin = buildDir / "tests" / "bin"
let testTmp = buildDir / "tests" / "tmp-core"
let testHome = testTmp / "home"
let nimcache = buildDir / "tests" / "nimcache-core"
let phase = getEnv("AVELRA_TEST_PHASE", "all")

if phase == "fail":
  # Deliberate failure used by CI to prove the runner propagates non-zero.
  echo "intentional test failure probe"
  quit(7)

proc run(command: string; args: seq[string]): int =
  let cmd = quoteShell(command) & " " & args.mapIt(quoteShell(it)).join(" ")
  echo "::group::", cmd
  let (output, code) = execCmdEx(cmd)
  echo output
  echo "::endgroup::"
  result = code

proc compileTest(name: string; source = "") =
  let sourcePath = if source.len > 0: source else: "tests/" & name & ".nim"
  var args = @[
    "c", "--hints:off", "--mm:orc", "--threads:on",
    "--path:src", "--path:tests",
    "--nimcache:" & nimcache,
    "--out:" & (testBin / (name & exe)),
    sourcePath]
  when defined(windows):
    args.insert("--cc:vcc", 2)
  let code = run("nim", args)
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
    "test_embedded_store", "test_pack_cli", "test_single_exe",
    "test_bind_error", "test_runtime_deps", "test_platform_checks",
    "test_cli_config", "test_cli_help", "test_cli_layout",
    "test_cli_init", "test_cli_build", "test_cli_run",
    "test_extension_config", "test_extension_host",
    "test_extension_manager", "test_static_server"]:
    runTest(name)

removeDir(testTmp)
createDir(testBin)
createDir(testHome)
createDir(nimcache)
putEnv("TMPDIR", testTmp)
putEnv("TEMP", testTmp)
putEnv("TMP", testTmp)
putEnv("AVELRA_HOME", buildDir)
putEnv("AVELRA_CLI", buildDir / "bin" / ("avelra" & exe))
putEnv("AVELRA_PACK", buildDir / "libexec" / "avelra" / ("avelra-pack" & exe))
putEnv("AVELRA_TEST_BIN", testBin)
compileTest("fake_runtime", "tests/fixtures/fake_runtime.nim")
compileTest("extension_echo", "tests/fixtures/extension_echo.nim")
compileTest("single_exe_harness", "tests/single_exe_harness.nim")
when defined(linux):
  if phase in ["all", "core"]:
    coreSuite()
    # Linux-specific implementations of the same semantic groups.
    runTest("test_installer")
    runTest("test_sdk_package")
    if run("bash", @["tests/test_release.sh"]) != 0:
      raise newException(OSError, "test failed: test_release.sh")
else:
  if phase in ["all", "core"]:
    coreSuite()
  if phase in ["all", "release"] and getEnv("AVELRA_TARGET").len > 0:
    runTest("test_package_contract")
    runTest("test_installer_platform")
    runTest("test_release_tree")
