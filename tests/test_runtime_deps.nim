## Runtime dependency evaluation without loading real GTK/WebKit.

import std/unittest

import cli/runtime_deps

let spec = LibrarySpec(
  display: "fake",
  library: "fake",
  minMajor: 3,
  minMinor: 24
)

suite "runtime dependency diagnostics":
  test "reports a missing library":
    let checks = evaluateLinux(@[
      LibraryProbe(spec: spec, present: false)
    ])
    check checks.len == 1
    check checks[0].state == depMissing

  test "reports an old version":
    let checks = evaluateLinux(@[
      LibraryProbe(spec: spec, present: true, version: "3.20.0")
    ])
    check checks[0].state == depTooOld
    check checks[0].version == "3.20.0"

  test "reports an unknown version":
    let checks = evaluateLinux(@[
      LibraryProbe(spec: spec, present: true)
    ])
    check checks[0].state == depUnknown

  test "counts non-ok results":
    let checks = @[
      DependencyResult(state: depMissing),
      DependencyResult(state: depOk),
      DependencyResult(state: depTooOld)
    ]
    check failures(checks) == 2
