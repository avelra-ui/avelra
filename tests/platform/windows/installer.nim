## Platform installer contract for Windows NSIS and macOS DMG.

import std/[os, osproc, strutils, unittest]

let version = readFile("VERSION").strip()
let label = getEnv("AVELRA_ARTIFACT_LABEL", version)
let target = getEnv("AVELRA_TARGET")
let releaseRoot = getEnv("AVELRA_RELEASE_DIR")
let release = releaseRoot / version / target

suite "installer contract":
  test "platform installer exists":
    case target
    of "windows-x64":
      let setup = release / "artifacts" / ("avelra-" & label & "-windows-x64-setup.exe")
      check fileExists(setup)
      let header = readFile(setup)
      check header.len >= 2
      check header[0..1] == "MZ"
    of "macos-x64":
      let dmg = release / "artifacts" / ("avelra-" & label & "-macos-x64.dmg")
      check fileExists(dmg)
    else:
      check false

  when defined(macosx):
    test "DMG contains the runtime tree":
      let dmg = release / "artifacts" / ("avelra-" & label & "-macos-x64.dmg")
      let mount = getTempDir() / ("avelra-dmg-" & $getCurrentProcessId())
      removeDir(mount)
      createDir(mount)
      let attach = execCmdEx("hdiutil attach -nobrowse -readonly -mountpoint " &
        quoteShell(mount) & " " & quoteShell(dmg))
      check attach.exitCode == 0
      try:
        check fileExists(mount / "bin" / "avelra")
        check fileExists(mount / "libexec" / "avelra" / "avelra-runtime")
      finally:
        discard execCmdEx("hdiutil detach " & quoteShell(mount))
        removeDir(mount)
