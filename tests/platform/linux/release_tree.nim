## Linux release-tree implementation.

import std/[os, osproc, unittest]

let script = currentSourcePath().parentDir / "release_tree.sh"

suite "release tree":
  test "Linux release tree builds and verifies":
    let result = execCmdEx("bash " & quoteShell(script))
    if result.exitCode != 0:
      echo result.output
    check result.exitCode == 0
