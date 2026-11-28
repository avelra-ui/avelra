## Cross-platform release tree contract for CI artifacts.
##
## Verifies the release layout and expected artifacts on Windows/macOS. The
## positive case runs against the assembled release; the negative cases copy
## the tree locally and prove that missing metadata/artifacts are rejected.

import std/[json, os, sequtils, strutils, unittest]

let version = readFile("VERSION").strip()
let label = getEnv("AVELRA_ARTIFACT_LABEL", version)
let target = getEnv("AVELRA_TARGET")
let releaseRoot = getEnv("AVELRA_RELEASE_DIR")
let releaseDir = releaseRoot / version / target

proc expectedArtifacts(target: string): seq[string] =
  case target
  of "linux-x64":
    @["avelra-" & label & "-linux-x64.tar.gz",
      "avelra_" & version & "_amd64.deb"]
  of "windows-x64":
    @["avelra-" & label & "-windows-x64.zip",
      "avelra-" & label & "-windows-x64-setup.exe"]
  of "macos-x64":
    @["avelra-" & label & "-macos-x64.tar.gz",
      "avelra-" & label & "-macos-x64.dmg"]
  else:
    @[]

proc validateRelease(root: string): seq[string] =
  if not dirExists(root):
    return @["release directory missing: " & root]
  let manifestPath = root / "manifest.json"
  let sumsPath = root / "SHA256SUMS"
  if not fileExists(manifestPath):
    result.add("manifest missing")
  if not fileExists(sumsPath):
    result.add("SHA256SUMS missing")
  if result.len > 0:
    return
  let manifest = parseFile(manifestPath)
  if manifest["version"].getStr() != version:
    result.add("manifest version mismatch")
  if manifest["target"].getStr() != target:
    result.add("manifest target mismatch")
  for name in expectedArtifacts(target):
    if not fileExists(root / "artifacts" / name):
      result.add("artifact missing: " & name)
  if not manifest.hasKey("files") or manifest["files"].kind != JArray:
    result.add("manifest files missing")
    return
  for entry in manifest["files"]:
    let path = root / "tree" / entry["path"].getStr()
    if not fileExists(path):
      result.add("tree file missing: " & path)
    elif getFileSize(path) != entry["size"].getBiggestInt():
      result.add("tree file size mismatch: " & path)

suite "release tree contract":
  test "assembled release tree is complete":
    check target in ["linux-x64", "windows-x64", "macos-x64"]
    check releaseRoot.len > 0
    check validateRelease(releaseDir).len == 0

  test "missing artifact is rejected":
    let copy = getTempDir() / ("avelra-release-negative-" & $getCurrentProcessId())
    removeDir(copy)
    copyDir(releaseDir, copy)
    try:
      removeFile(copy / "artifacts" / expectedArtifacts(target)[0])
      check validateRelease(copy).anyIt(it.startsWith("artifact missing:"))
    finally:
      removeDir(copy)

  test "missing manifest is rejected":
    let copy = getTempDir() / ("avelra-release-manifest-" & $getCurrentProcessId())
    removeDir(copy)
    copyDir(releaseDir, copy)
    try:
      removeFile(copy / "manifest.json")
      check validateRelease(copy).contains("manifest missing")
    finally:
      removeDir(copy)
