## Canonical cross-platform test entrypoint.
##
## Three equal platforms: linux, windows, macos. Required semantic groups are
## declared in tests/required-groups.txt; platform implementations live under
## tests/platform/<os>/<group>.nim. Missing group coverage is a hard failure.

import std/[os, osproc, sequtils, strutils]

const root = currentSourcePath().parentDir.parentDir
const exe = when defined(windows): ".exe" else: ""

let buildDir = root / "build"
let testBin = buildDir / "tests" / "bin"
let testTmp = buildDir / "tests" / "tmp-core"
let testHome = testTmp / "home"
let nimcache = buildDir / "tests" / "nimcache-core"
let phase = getEnv("AVELRA_TEST_PHASE", "all")
const platformName = when defined(linux): "linux"
  elif defined(windows): "windows"
  elif defined(macosx): "macos"
  else: "unknown"
const commonGroups = ["core", "runtime_deps"]
let requiredGroups = readFile(root / "tests" / "required-groups.txt")
  .splitLines()
  .mapIt(it.strip)
  .filterIt(it.len > 0 and not it.startsWith("#"))

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

proc runTestPath(name: string; source: string) =
  compileTest(name, source)
  let code = run(testBin / (name & exe), @[])
  if code != 0:
    raise newException(OSError, "test failed: " & name)

proc coreSuite()

proc runGroup(group: string) =
  if group == "core":
    coreSuite()
  elif group == "runtime_deps":
    runTest("test_runtime_deps")
  else:
    let source = "tests/platform" / platformName / (group & ".nim")
    if not fileExists(source):
      raise newException(OSError,
        "missing semantic group " & group & " for " & platformName)
    runTestPath(group, source)

proc coreSuite() =
  for name in [
    "test_native_call", "test_dispatcher", "test_url_policy",
    "test_static_paths", "test_resource_store", "test_zip", "test_payload",
    "test_embedded_store", "test_pack_cli", "test_single_exe",
    "test_bind_error", "test_platform_checks",
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

# Coverage gate: every non-common required group must exist for this platform.
for group in requiredGroups:
  if group notin commonGroups and not fileExists("tests/platform" / platformName / (group & ".nim")):
    raise newException(OSError,
      "missing semantic group " & group & " for " & platformName)

compileTest("fake_runtime", "tests/fixtures/fake_runtime.nim")
compileTest("extension_echo", "tests/fixtures/extension_echo.nim")
compileTest("single_exe_harness", "tests/single_exe_harness.nim")

if phase in ["all", "core"]:
  runGroup("core")
  runGroup("runtime_deps")

if phase in ["all", "release"] and getEnv("AVELRA_TARGET").len > 0:
  for group in requiredGroups:
    if group notin commonGroups:
      runGroup(group)
