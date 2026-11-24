## Platform-neutral runtime dependency diagnostics.

import std/unittest

import cli/runtime_deps

proc systemLibrary(): string =
  when defined(linux):
    "libc.so.6"
  elif defined(macosx):
    "libSystem.B.dylib"
  elif defined(windows):
    "kernel32.dll"
  else:
    ""

suite "runtime dependency diagnostics":
  test "missing library is reported":
    let checks = diagnose(@[
      LibrarySpec(display: "missing", library: "/nonexistent/avelra-test-lib")
    ])
    check checks.len == 1
    check checks[0].state == depMissing

  test "system library is loadable":
    let checks = diagnose(@[LibrarySpec(display: "system", library: systemLibrary())])
    check checks.len == 1
    check checks[0].state in {depOk, depUnknown}

  test "failures counts non-ok results":
    let checks = @[
      DependencyResult(state: depMissing),
      DependencyResult(state: depOk),
      DependencyResult(state: depUnknown)
    ]
    check failures(checks) == 2
