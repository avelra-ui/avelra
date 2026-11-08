## The user-facing CLI exposes help and version.

import std/[osproc, strutils, unittest]

import support

suite "avelra CLI":
  test "help lists commands":
    let result = execCmdEx(cliPath() & " --help")
    check result.exitCode == 0
    check result.output.contains("init")
    check result.output.contains("installer")

  test "version is printed":
    let result = execCmdEx(cliPath() & " --version")
    check result.exitCode == 0
    check result.output.contains("avelra")
