## Shared paths for tests; the runner overrides them with absolute paths.

import std/os

proc cliPath*(): string =
  result = getEnv("AVELRA_CLI")
  if result.len == 0:
    result = "build/bin/avelra"

proc packPath*(): string =
  result = getEnv("AVELRA_PACK")
  if result.len == 0:
    result = "build/libexec/avelra/avelra-pack"

proc testBin*(name: string): string =
  var directory = getEnv("AVELRA_TEST_BIN")
  if directory.len == 0:
    directory = "build/tests/bin"
  directory / name
