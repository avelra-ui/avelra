# Build webview/webview as a static MSVC library for Windows x64.
# Unverified: run on Windows with Visual Studio 2022 Build Tools and CMake.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BuildDir = if ($env:BUILD_DIR) { $env:BUILD_DIR } else { Join-Path $Root "build" }
Set-Location $Root

$Version = "0.12.0"
$Src = Join-Path $BuildDir "webview-src"
$Build = Join-Path $Src "build-win"

if (-not (Test-Path (Join-Path $Src ".git"))) {
    if (Test-Path $Src) { Remove-Item -Recurse -Force $Src }
    git clone --depth 1 --branch $Version https://github.com/webview/webview.git $Src
}

# webview fetches the WebView2 SDK from NuGet unless it is already installed.
cmake -S $Src -B $Build -G "Visual Studio 17 2022" -A x64 `
    -DCMAKE_BUILD_TYPE=Release `
    -DWEBVIEW_BUILD=ON `
    -DWEBVIEW_BUILD_STATIC_LIBRARY=ON `
    -DWEBVIEW_ENABLE_CHECKS=OFF `
    -DWEBVIEW_BUILD_SHARED_LIBRARY=OFF `
    -DWEBVIEW_BUILD_EXAMPLES=OFF `
    -DWEBVIEW_BUILD_TESTS=OFF `
    -DWEBVIEW_BUILD_DOCS=OFF `
    -DWEBVIEW_USE_BUILTIN_MSWEBVIEW2=ON

cmake --build $Build --config Release --parallel

$Lib = Get-ChildItem -Path $Build -Recurse -Filter "webview_static.lib" |
    Select-Object -First 1
if (-not $Lib) { throw "webview_static.lib was not produced" }

$OutLib = Join-Path $BuildDir "vendor/webview/windows/lib"
$OutInclude = Join-Path $Root "vendor/webview/include/webview"
New-Item -ItemType Directory -Force -Path $OutLib, $OutInclude | Out-Null

Copy-Item $Lib.FullName (Join-Path $OutLib "webview_static.lib") -Force
Copy-Item (Join-Path $Src "core/include/webview/webview.h") `
    (Join-Path $OutInclude "webview.h") -Force

Write-Host "Built $OutLib/webview_static.lib"
