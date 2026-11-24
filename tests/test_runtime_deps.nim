## Runtime dependency inspection without starting GTK/WebKit.

import std/[os, unittest]

import cli/runtime_deps

const libExt =
  when defined(windows): ".dll"
  elif defined(macosx): ".dylib"
  else: ".so"

let testBin = getEnv("AVELRA_TEST_BIN", "build/tests/bin")
let versionLib = testBin / ("fake_version_lib" & libExt)
let emptyLib = testBin / ("fake_empty_lib" & libExt)

suite "runtime dependency diagnostics":
  test "reports a missing library":
    let checks = diagnose(@[
      LibrarySpec(display: "missing", library: "/nonexistent/avelra-test-lib")
    ])
    check checks.len == 1
    check checks[0].state == depMissing

  test "reports an old version":
    let checks = diagnose(@[
      LibrarySpec(
        display: "old", library: versionLib,
        minMajor: 3, minMinor: 24,
        majorSymbol: "fake_major_version",
        minorSymbol: "fake_minor_version",
        microSymbol: "fake_micro_version"
      )
    ])
    check checks[0].state == depTooOld
    check checks[0].version == "3.20.0"

  test "reports an unknown version":
    let checks = diagnose(@[
      LibrarySpec(
        display: "unknown", library: emptyLib,
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
