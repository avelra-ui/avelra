## Loadable library without version symbols.

proc fake_dummy*(): cint {.exportc, dynlib.} = 1
