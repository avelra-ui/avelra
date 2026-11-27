## Platform package contract: manifest, checksums and expected artifact names.

import std/[json, os, strutils, unittest]

let version = readFile("VERSION").strip()
let label = getEnv("AVELRA_ARTIFACT_LABEL", version)
let target = getEnv("AVELRA_TARGET")
let releaseRoot = getEnv("AVELRA_RELEASE_DIR")
let release = releaseRoot / version / target

proc expectedArtifacts(): seq[string] =
  case target
  of "linux-x64":
    @["avelra-" & label & "-linux-x64.tar.gz", "avelra_" & version & "_amd64.deb"]
  of "windows-x64":
    @["avelra-" & label & "-windows-x64.zip",
      "avelra-" & label & "-windows-x64-setup.exe"]
  of "macos-x64":
    @["avelra-" & label & "-macos-x64.tar.gz",
      "avelra-" & label & "-macos-x64.dmg"]
  else:
    @[]

suite "package contract":
  test "target is supported":
    check target in ["linux-x64", "windows-x64", "macos-x64"]
    check releaseRoot.len > 0

  test "manifest and checksums exist":
    check fileExists(release / "manifest.json")
    check fileExists(release / "SHA256SUMS")

  test "expected artifacts exist":
    let expected = expectedArtifacts()
    check expected.len > 0
    for name in expected:
      check fileExists(release / "artifacts" / name)

  test "manifest identifies target and version":
    let manifest = parseFile(release / "manifest.json")
    check manifest["version"].getStr() == version
    check manifest["target"].getStr() == target

  test "checksums cover assembled artifacts":
    let sums = readFile(release / "SHA256SUMS")
    for name in expectedArtifacts():
      # NSIS/DMG are added after assemble.py writes its initial SHA256SUMS;
      # release verification recomputes the final per-target checksums.
      if not (name.endsWith("-setup.exe") or name.endsWith(".dmg")):
        check sums.contains(name)
