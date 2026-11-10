## Runtime dependency inspection without starting GTK/WebKit.

import std/unittest

import cli/runtime_deps

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

  test "counts non-ok results":
    let checks = @[
      DependencyResult(state: depMissing),
      DependencyResult(state: depOk),
      DependencyResult(state: depTooOld)
    ]
    check failures(checks) == 2
