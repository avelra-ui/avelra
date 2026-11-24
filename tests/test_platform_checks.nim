## Platform compatibility checks without Windows/macOS hosts.

import std/unittest

import cli/platform_checks

suite "platform checks":
  test "compares versions numerically":
    check versionCmp("10.0.17763", "10.0.19045") < 0
    check versionCmp("10.0.19044", "10.0.19044") == 0
    check versionCmp("10.0.19043", "10.0.19044") < 0
    check versionCmp("12.0", "11.7") > 0
    check versionCmp("120.0.1", "120.0.1") == 0

  test "supported Windows snapshot":
    let checks = evaluateWindows(PlatformSnapshot(
      osVersion: "10.0.19044",
      arch: "AMD64",
      webView2Version: "120.0.2210.91",
      vcRuntime: true
    ))
    check failures(checks) == 0

  test "missing Windows dependencies":
    let checks = evaluateWindows(PlatformSnapshot(
      osVersion: "6.1.7601",
      arch: "AMD64"
    ))
    check failures(checks) == 3

  test "supported macOS snapshot":
    let checks = evaluateMacos(PlatformSnapshot(
      osVersion: "14.5",
      arch: "x86_64",
      webKitPresent: true
    ))
    check failures(checks) == 0

  test "unsupported macOS snapshot":
    let checks = evaluateMacos(PlatformSnapshot(
      osVersion: "11.7",
      arch: "arm64",
      webKitPresent: false
    ))
    check failures(checks) == 3
