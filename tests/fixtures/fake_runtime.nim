## Writes its argv to AVELRA_FAKE_ARGS and exits with a sentinel code.

import std/[os, strutils]

let output = getEnv("AVELRA_FAKE_ARGS")
if output.len > 0:
  writeFile(output, commandLineParams().join("\n"))
quit(7)
