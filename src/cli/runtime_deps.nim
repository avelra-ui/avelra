## Linux runtime dependency diagnostics.
##
## The CLI itself is linked only against libc. GTK and WebKitGTK are loaded
## dynamically so `avelra doctor` can report missing libraries instead of
## letting the dynamic loader fail before `avelra-runtime` starts.

import std/[dynlib, strutils]

when defined(linux):
  import std/os

type
  DependencyState* = enum
    depOk, depMissing, depTooOld, depUnknown

  LibrarySpec* = object
    display*: string
    library*: string
    hint*: string
    minMajor*: int
    minMinor*: int
    majorSymbol*: string
    minorSymbol*: string
    microSymbol*: string

  DependencyResult* = object
    spec*: LibrarySpec
    state*: DependencyState
    version*: string

proc readVersion(lib: LibHandle; spec: LibrarySpec):
    tuple[ok: bool, major, minor, micro: int] =
  if spec.majorSymbol.len == 0:
    return (true, 0, 0, 0)
  let majorPtr = symAddr(lib, cstring(spec.majorSymbol))
  let minorPtr = symAddr(lib, cstring(spec.minorSymbol))
  let microPtr = symAddr(lib, cstring(spec.microSymbol))
  if majorPtr == nil or minorPtr == nil or microPtr == nil:
    return (false, 0, 0, 0)
  let major = cast[proc(): cuint {.cdecl.}](majorPtr)()
  let minor = cast[proc(): cuint {.cdecl.}](minorPtr)()
  let micro = cast[proc(): cuint {.cdecl.}](microPtr)()
  (true, int(major), int(minor), int(micro))

proc diagnose*(specs: openArray[LibrarySpec]): seq[DependencyResult] =
  ## Inspect each library without starting GTK or a WebKit process.
  for spec in specs:
    let lib = loadLib(spec.library)
    if lib == nil:
      result.add DependencyResult(spec: spec, state: depMissing)
      continue
    let version = readVersion(lib, spec)
    unloadLib(lib)
    if not version.ok:
      result.add DependencyResult(spec: spec, state: depUnknown)
    elif version.major < spec.minMajor or
        (version.major == spec.minMajor and version.minor < spec.minMinor):
      result.add DependencyResult(
        spec: spec,
        state: depTooOld,
        version: "$1.$2.$3" % [$version.major, $version.minor, $version.micro]
      )
    else:
      result.add DependencyResult(
        spec: spec,
        state: depOk,
        version: "$1.$2.$3" % [$version.major, $version.minor, $version.micro]
      )

proc osRelease(): string =
  try:
    readFile("/etc/os-release")
  except CatchableError:
    ""

proc packageHint(name: string): string =
  let release = osRelease()
  let isUbuntu = release.contains("ID=ubuntu")
  let isDebian = release.contains("ID=debian")
  let isFedora = release.contains("ID=fedora")
  let isArch = release.contains("ID=arch")
  case name
  of "gtk":
    if isUbuntu:
      "sudo apt install libgtk-3-0t64"
    elif isDebian:
      "sudo apt install libgtk-3-0"
    elif isFedora:
      "sudo dnf install gtk3"
    elif isArch:
      "sudo pacman -S gtk3"
    else:
      "install GTK 3 for your distribution"
  of "webkit":
    if isFedora:
      "sudo dnf install webkit2gtk4.1"
    elif isArch:
      "sudo pacman -S webkit2gtk-4.1"
    else:
      "sudo apt install libwebkit2gtk-4.1-0"
  else:
    "install the missing runtime dependency"

proc linuxRuntimeSpecs*(): seq[LibrarySpec] =
  @[
    LibrarySpec(
      display: "GTK 3",
      library: "libgtk-3.so.0",
      hint: packageHint("gtk"),
      minMajor: 3,
      minMinor: 24,
      majorSymbol: "gtk_get_major_version",
      minorSymbol: "gtk_get_minor_version",
      microSymbol: "gtk_get_micro_version"
    ),
    LibrarySpec(
      display: "WebKitGTK 4.1",
      library: "libwebkit2gtk-4.1.so.0",
      hint: packageHint("webkit"),
      minMajor: 2,
      minMinor: 40,
      majorSymbol: "webkit_get_major_version",
      minorSymbol: "webkit_get_minor_version",
      microSymbol: "webkit_get_micro_version"
    )
  ]

proc failures*(results: openArray[DependencyResult]): int =
  for item in results:
    if item.state != depOk:
      inc result

proc printDoctor*(results: openArray[DependencyResult]) =
  echo "Avelra runtime dependencies (Linux)"
  for item in results:
    case item.state
    of depOk:
      echo "  ", item.spec.display, ": OK (", item.version, ")"
    of depMissing:
      echo "  ", item.spec.display, ": MISSING"
      echo "    hint: ", item.spec.hint
    of depTooOld:
      echo "  ", item.spec.display, ": too old (", item.version, "; need >= ",
        item.spec.minMajor, ".", item.spec.minMinor, ")"
      echo "    hint: ", item.spec.hint
    of depUnknown:
      echo "  ", item.spec.display, ": present, but version is unknown"
      echo "    hint: ", item.spec.hint
  if failures(results) == 0:
    echo "status: OK"
  else:
    echo "status: FAILED"

when defined(linux):
  proc runtimePreflight*(): bool =
    if getEnv("AVELRA_SKIP_PREFLIGHT") == "1":
      return true
    let results = diagnose(linuxRuntimeSpecs())
    if failures(results) == 0:
      return true
    for item in results:
      if item.state != depOk:
        stderr.writeLine("avelra: ", item.spec.display, " is unavailable")
        stderr.writeLine("  hint: ", item.spec.hint)
    stderr.writeLine("Run 'avelra doctor' for details.")
    false
else:
  proc runtimePreflight*(): bool = true
