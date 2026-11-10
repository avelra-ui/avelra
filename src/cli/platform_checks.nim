## Platform compatibility checks for Windows and macOS.
##
## The evaluation helpers are pure so they can be unit-tested on any host.
## Snapshot probes are compiled only for the target platform.

import std/[os, strutils]

when defined(windows) or defined(macosx):
  import std/osproc

type
  CheckState* = enum
    checkOk, checkMissing, checkTooOld, checkUnknown

  CheckResult* = object
    display*: string
    detail*: string
    hint*: string
    state*: CheckState

  PlatformSnapshot* = object
    osVersion*: string
    arch*: string
    webView2Version*: string
    vcRuntime*: bool
    webKitPresent*: bool

const
  MinWindowsVersion* = "10.0.17763"   # Windows 10 1809
  MinWebView2Version* = "100.0.0"
  MinMacosVersion* = "12.0"

proc parseVersion*(value: string): tuple[major, minor, patch: int] =
  let parts = value.strip.split('.')
  if parts.len == 0:
    return (0, 0, 0)
  try:
    if parts.len >= 1: result.major = parseInt(parts[0])
    if parts.len >= 2: result.minor = parseInt(parts[1])
    if parts.len >= 3: result.patch = parseInt(parts[2])
  except ValueError:
    return (0, 0, 0)

proc versionCmp*(left, right: string): int =
  let a = parseVersion(left)
  let b = parseVersion(right)
  if a.major != b.major: return cmp(a.major, b.major)
  if a.minor != b.minor: return cmp(a.minor, b.minor)
  cmp(a.patch, b.patch)

proc stateForVersion*(actual, minimum: string): CheckState =
  if actual.len == 0:
    return checkMissing
  let parsed = parseVersion(actual)
  if parsed == (0, 0, 0):
    return checkUnknown
  if versionCmp(actual, minimum) < 0:
    return checkTooOld
  checkOk

proc checkVersion*(display, actual, minimum, hint: string): CheckResult =
  result = CheckResult(display: display, detail: actual, hint: hint)
  result.state = stateForVersion(actual, minimum)
  if result.state == checkMissing:
    result.detail = "not found (need >= " & minimum & ")"
  elif result.state == checkTooOld:
    result.detail = actual & " (need >= " & minimum & ")"
  elif result.state == checkUnknown:
    result.detail = actual & " (version is not parseable)"

proc latestVersionInDirectories*(root: string): string =
  if not dirExists(root):
    return ""
  for kind, path in walkDir(root):
    if kind == pcDir:
      let candidate = lastPathPart(path)
      if parseVersion(candidate) != (0, 0, 0):
        if result.len == 0 or versionCmp(candidate, result) > 0:
          result = candidate

proc evaluateWindows*(snapshot: PlatformSnapshot): seq[CheckResult] =
  result.add checkVersion(
    "Windows", snapshot.osVersion, MinWindowsVersion,
    "update Windows to 10.0.17763 or newer"
  )
  result.add checkVersion(
    "WebView2 Runtime", snapshot.webView2Version, MinWebView2Version,
    "install Microsoft Edge WebView2 Evergreen Runtime"
  )
  if snapshot.vcRuntime:
    result.add CheckResult(display: "VC++ 2015-2022 x64 runtime",
      detail: "present", state: checkOk)
  else:
    result.add CheckResult(display: "VC++ 2015-2022 x64 runtime",
      detail: "not found", state: checkMissing,
      hint: "install Microsoft Visual C++ 2015-2022 Redistributable (x64)")

proc evaluateMacos*(snapshot: PlatformSnapshot): seq[CheckResult] =
  result.add checkVersion(
    "macOS", snapshot.osVersion, MinMacosVersion,
    "update macOS to 12.0 or newer"
  )
  if snapshot.arch == "arm64":
    result.add CheckResult(display: "architecture", detail: "arm64",
      state: checkOk)
  else:
    result.add CheckResult(display: "architecture",
      detail: snapshot.arch & " (arm64 required)", state: checkTooOld,
      hint: "use the arm64 Avelra build")
  if snapshot.webKitPresent:
    result.add CheckResult(display: "WebKit framework", detail: "present",
      state: checkOk)
  else:
    result.add CheckResult(display: "WebKit framework", detail: "not found",
      state: checkMissing, hint: "restore the macOS system WebKit framework")

proc failures*(checks: openArray[CheckResult]): int =
  for item in checks:
    if item.state != checkOk:
      inc result

when defined(windows):
  proc windowsVersion(): string =
    let output = execCmdEx("cmd /c ver").output
    for token in output.splitWhitespace:
      if token.len > 0 and token[0].isDigit and token.contains('.'):
        return token.strip(chars = {'[', ']'})

  proc windowsSnapshot*(): PlatformSnapshot =
    let programFiles = getEnv("ProgramFiles(x86)")
    let localAppData = getEnv("LOCALAPPDATA")
    let root1 = programFiles / "Microsoft/EdgeWebView/Application"
    let root2 = localAppData / "Microsoft/EdgeWebView/Application"
    let webView2 = block:
      let a = latestVersionInDirectories(root1)
      let b = latestVersionInDirectories(root2)
      if a.len == 0: b
      elif b.len == 0: a
      elif versionCmp(a, b) >= 0: a
      else: b
    let systemRoot = getEnv("SystemRoot")
    result = PlatformSnapshot(
      osVersion: windowsVersion(),
      arch: getEnv("PROCESSOR_ARCHITECTURE"),
      webView2Version: webView2,
      vcRuntime: fileExists(systemRoot / "System32/vcruntime140.dll") and
                 fileExists(systemRoot / "System32/msvcp140.dll")
    )
elif defined(macosx):
  proc macosSnapshot*(): PlatformSnapshot =
    result = PlatformSnapshot(
      osVersion: execCmdEx("sw_vers -productVersion").output.strip(),
      arch: execCmdEx("uname -m").output.strip(),
      webKitPresent: fileExists("/System/Library/Frameworks/WebKit.framework")
    )

proc printChecks*(title: string; checks: openArray[CheckResult]) =
  echo title
  for item in checks:
    case item.state
    of checkOk:
      echo "  ", item.display, ": OK (", item.detail, ")"
    of checkMissing:
      echo "  ", item.display, ": MISSING"
      echo "    ", item.detail
      if item.hint.len > 0: echo "    hint: ", item.hint
    of checkTooOld:
      echo "  ", item.display, ": unsupported"
      echo "    ", item.detail
      if item.hint.len > 0: echo "    hint: ", item.hint
    of checkUnknown:
      echo "  ", item.display, ": unknown"
      echo "    ", item.detail
      if item.hint.len > 0: echo "    hint: ", item.hint
  echo "status: ", (if failures(checks) == 0: "OK" else: "FAILED")

when defined(windows) or defined(macosx):
  proc platformPreflight*(): bool =
    let checks =
      when defined(windows): evaluateWindows(windowsSnapshot())
      else: evaluateMacos(macosSnapshot())
    if failures(checks) == 0:
      return true
    for item in checks:
      if item.state != checkOk:
        stderr.writeLine("avelra: ", item.display, " is unavailable")
        if item.hint.len > 0: stderr.writeLine("  hint: ", item.hint)
    stderr.writeLine("Run 'avelra doctor' for details.")
    false
