## Fake runtime library with version symbols for dependency diagnostics.

proc fake_major_version*(): cuint {.exportc, dynlib.} = 3
proc fake_minor_version*(): cuint {.exportc, dynlib.} = 20
proc fake_micro_version*(): cuint {.exportc, dynlib.} = 0
