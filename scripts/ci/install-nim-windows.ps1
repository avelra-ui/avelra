# Install the official prebuilt Nim archive on Windows x64.
param(
    [string]$Version = "2.2.12"
)

$ErrorActionPreference = "Stop"

$sha256 = "dafe9c81f8118fac2e07ee24f3649448a590d8b0f3b55d1a97c66f99035cc8e6"
$url = "https://nim-lang.org/download/nim-$Version-x64.zip"
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$archive = Join-Path $tmp "nim-$Version.zip"
$nimRoot = Join-Path $tmp "nim-$Version"

Invoke-WebRequest -Uri $url -OutFile $archive
$actual = (Get-FileHash -Algorithm SHA256 -Path $archive).Hash.ToLowerInvariant()
if ($actual -ne $sha256) {
    throw "Nim archive checksum mismatch: $actual"
}

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $nimRoot
Expand-Archive -Path $archive -DestinationPath $tmp -Force
$nimBin = Join-Path $nimRoot "bin"
[System.IO.File]::AppendAllText($env:GITHUB_PATH, "$nimBin`n")
& (Join-Path $nimBin "nim.exe") -v
