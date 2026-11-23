# Package a staged Windows SDK release as an unsigned NSIS installer.
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDir,
    [string]$ArtifactLabel = ""
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ReleaseDir = (Resolve-Path $ReleaseDir).Path
$Tree = Join-Path $ReleaseDir "tree"
$Artifacts = Join-Path $ReleaseDir "artifacts"
$Version = (Get-Content (Join-Path $Root "VERSION") -Raw).Trim()
if (-not $ArtifactLabel) { $ArtifactLabel = $Version }
$Output = Join-Path $Artifacts "avelra-$ArtifactLabel-windows-x64-setup.exe"
$Nsi = Join-Path $env:TEMP "avelra-$ArtifactLabel.nsi"

if (-not (Test-Path (Join-Path $Tree "bin/avelra.exe"))) {
    throw "release tree is missing bin/avelra.exe: $Tree"
}
if (-not (Get-Command makensis -ErrorAction SilentlyContinue)) {
    throw "makensis is required (choco install nsis)"
}
New-Item -ItemType Directory -Force -Path $Artifacts | Out-Null
$TreeForNsis = $Tree.Replace('/', '\')

$Script = @"
!include "MUI2.nsh"
Name "Avelra"
OutFile "$($Output.Replace('/', '\'))"
InstallDir "`$LOCALAPPDATA\Avelra"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Avelra" SecMain
  SetOutPath "`$INSTDIR"
  File /r "$TreeForNsis\*"
  WriteUninstaller "`$INSTDIR\uninstall.exe"
  CreateDirectory "`$SMPROGRAMS\Avelra"
  CreateShortcut "`$SMPROGRAMS\Avelra\Avelra CLI.lnk" "`$INSTDIR\bin\avelra.exe"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "DisplayName" "Avelra"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "DisplayVersion" "$Version"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "Publisher" "Avelra"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "InstallLocation" "`$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "UninstallString" '"`$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "DisplayIcon" "`$INSTDIR\bin\avelra.exe"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra" "NoRepair" 1
SectionEnd

Section "Uninstall"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Avelra"
  SetOutPath "`$TEMP"
  RMDir /r "`$INSTDIR"
  Delete "`$INSTDIR\uninstall.exe"
  RMDir "`$INSTDIR"
  Delete "`$SMPROGRAMS\Avelra\Avelra CLI.lnk"
  RMDir "`$SMPROGRAMS\Avelra"
SectionEnd
"@
Set-Content -Path $Nsi -Value $Script -Encoding UTF8
& makensis $Nsi
if ($LASTEXITCODE -ne 0) { throw "makensis failed" }

$hash = (Get-FileHash $Output -Algorithm SHA256).Hash.ToLower()
Add-Content -Path (Join-Path $ReleaseDir "SHA256SUMS") -Value "$hash  $(Split-Path -Leaf $Output)"
Write-Host "installer: $Output"
