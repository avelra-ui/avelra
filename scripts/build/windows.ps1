# Build Avelra for Windows x64.
# Experimental and unverified: run from a Developer PowerShell with MSVC
# (Visual Studio 2022 Build Tools) and Nim available in PATH.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root

$BuildDir = if ($env:BUILD_DIR) { $env:BUILD_DIR } else { Join-Path $Root "build" }
$BinDir = Join-Path $BuildDir "bin"
$LibExec = if ($env:LIBEXEC_DIR) { $env:LIBEXEC_DIR } else { Join-Path $BuildDir "libexec/avelra" }
$Share = Join-Path $BuildDir "share/avelra/templates/app"
$Lib = Join-Path $BuildDir "vendor/webview/windows/lib/webview_static.lib"

New-Item -ItemType Directory -Force -Path $BinDir, $LibExec, (Join-Path $BuildDir "nimcache-win") | Out-Null
$Version = (Get-Content (Join-Path $Root "VERSION") -Raw).Trim()
$Common = @(
    "c", "-d:release", "--opt:size", "--mm:orc", "-d:strip", "--hints:off",
    "--os:windows", "--cpu:amd64", "--cc:vcc", "--path:src",
    "-d:avelraVersion=$Version"
)
if (-not (Test-Path $Lib)) {
    & (Join-Path $Root "scripts/webview/windows.ps1")
}
if (-not (Test-Path $Lib)) {
    throw "webview_static.lib is missing; run scripts/webview/windows.ps1"
}

# MSVC runtime and library order must match the static webview build.
$NimArgs = @(
    "c",
    "-d:release", "--opt:size", "--mm:orc", "-d:strip", "--hints:off",
    "--threads:on",
    "--os:windows", "--cpu:amd64", "--cc:vcc", "--app:gui",
    "--path:src",
    "--nimcache:$(Join-Path $BuildDir 'nimcache-win')",
    "--out:$(Join-Path $LibExec 'avelra-runtime.exe')",
    "--passC:/MD", "--passL:/MD",
    "--passL:$Lib",
    "--passL:advapi32.lib",
    "--passL:ole32.lib",
    "--passL:shell32.lib",
    "--passL:shlwapi.lib",
    "--passL:user32.lib",
    "--passL:version.lib",
    "src/avelra.nim"
)

& nim @NimArgs

& nim @Common `
    --nimcache:"$(Join-Path $BuildDir 'nimcache-cli')" `
    --out:"$(Join-Path $BinDir 'avelra.exe')" `
    src/bin/avelra_cli.nim

& nim @Common `
    --threads:on `
    --nimcache:"$(Join-Path $BuildDir 'nimcache-pack')" `
    --out:"$(Join-Path $LibExec 'avelra-pack.exe')" `
    src/bin/avelra_pack.nim

# Stage the template so the dev prefix stays a valid SDK layout.
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Share) | Out-Null
if (Test-Path $Share) { Remove-Item -Recurse -Force $Share }
Copy-Item (Join-Path $Root "share/avelra/templates/app") $Share -Recurse
