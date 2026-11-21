## Runtime dependency inspection without starting GTK/WebKit.

import std/[os, osproc, strutils, unittest]

import cli/runtime_deps

proc fakeLibrary(name, source: string): string =
  let dir = getTempDir() / ("avelra-runtime-deps-" & $getCurrentProcessId())
  createDir(dir)
  let src = dir / (name & ".c")
  let lib = dir / ("lib" & name & ".so")
  writeFile(src, source)
  let result = execCmdEx("cc -shared -fPIC -o " & quoteShell(lib) &
    " " & quoteShell(src))
  if result.exitCode != 0:
    checkpoint(result.output)
  check result.exitCode == 0
  lib

suite "runtime dependency diagnostics":
  test "reports a missing library":
    let checks = diagnose(@[
      LibrarySpec(display: "missing", library: "/nonexistent/avelra-test-lib.so")
    ])
    check checks.len == 1
    check checks[0].state == depMissing

  test "reports a loadable library":
    let checks = diagnose(@[
      LibrarySpec(display: "libc", library: "libc.so.6")
    ])
    check checks.len == 1
    check checks[0].state == depOk

  test "reports an old version":
    let lib = fakeLibrary("old", """
unsigned int fake_major_version(void) { return 3; }
unsigned int fake_minor_version(void) { return 20; }
unsigned int fake_micro_version(void) { return 0; }
""")
    let checks = diagnose(@[
      LibrarySpec(
        display: "old", library: lib,
        minMajor: 3, minMinor: 24,
        majorSymbol: "fake_major_version",
        minorSymbol: "fake_minor_version",
        microSymbol: "fake_micro_version"
      )
    ])
    check checks[0].state == depTooOld
    check checks[0].version == "3.20.0"

  test "reports an unknown version":
    let lib = fakeLibrary("unknown", "int fake(void) { return 1; }\n")
    let checks = diagnose(@[
      LibrarySpec(
        display: "unknown", library: lib,
        minMajor: 3, minMinor: 24,
        majorSymbol: "fake_major_version",
        minorSymbol: "fake_minor_version",
        microSymbol: "fake_micro_version"
      )
    ])
    check checks[0].state == depUnknown

  test "counts non-ok results":
    let checks = @[
      DependencyResult(state: depMissing),
      DependencyResult(state: depOk),
      DependencyResult(state: depTooOld)
    ]
    check failures(checks) == 2
