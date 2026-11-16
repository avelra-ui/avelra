## Linux installer builder for user applications.

import std/[os, osproc, strutils]

import cli/config

type
  InstallerTarget* = enum
    installerTar
    installerDeb
    installerAppImage

proc parseInstallerTarget*(value: string): InstallerTarget =
  case value.toLowerAscii()
  of "tar", "tar.gz": installerTar
  of "deb": installerDeb
  of "appimage", "appimage-x86_64": installerAppImage
  else:
    raise newException(ValueError, "unsupported target: " & value)

proc validateIdentifier(identifier: string) =
  if identifier.len == 0:
    raise newException(ValueError, "identifier must not be empty")
  for ch in identifier:
    if ch notin {'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '_', '-'}:
      raise newException(ValueError, "identifier contains unsupported characters")

proc copyExecutable(source, destination: string) =
  createDir(parentDir(destination))
  copyFile(source, destination)
  setFilePermissions(destination, {
    fpUserRead, fpUserWrite, fpUserExec,
    fpGroupRead, fpGroupExec,
    fpOthersRead, fpOthersExec
  })

proc desktopEntry(config: AppConfig; slug, iconName: string): string =
  result = "[Desktop Entry]\n" &
    "Type=Application\n" &
    "Name=" & config.name & "\n" &
    "Exec=" & slug & "\n" &
    "Terminal=false\n" &
    "Categories=Utility;\n" &
    "StartupWMClass=" & slug & "\n"
  if iconName.len > 0:
    result.add "Icon=" & iconName & "\n"

proc iconSource(configPath: string; config: AppConfig): string =
  if config.icon.len == 0:
    return ""
  if isAbsolute(config.icon):
    return config.icon
  projectDir(configPath) / config.icon

proc installIcon(source, destination: string) =
  if source.len == 0:
    return
  if not fileExists(source):
    raise newException(IOError, "icon not found: " & source)
  createDir(parentDir(destination))
  copyFile(source, destination)

proc defaultOutput(configPath: string; config: AppConfig; target: InstallerTarget): string =
  let extension = case target
    of installerTar: ".tar.gz"
    of installerDeb: ".deb"
    of installerAppImage: ".AppImage"
  projectDir(configPath) / "dist" / slugify(config.name) /
    (slugify(config.name) & "-" & config.version & "-linux-x64" & extension)

proc buildTar(binary, configPath: string; config: AppConfig; output: string) =
  let staging = getTempDir() / ("avelra-tar-" & $getCurrentProcessId())
  let slug = slugify(config.name)
  let bundleName = slug & "-" & config.version
  let bundle = staging / bundleName
  removeDir(staging)
  createDir(bundle)
  try:
    copyExecutable(binary, bundle / slug)
    let icon = iconSource(configPath, config)
    let hasIcon = icon.len > 0
    let desktop = bundle / "share" / "applications" / (slug & ".desktop")
    createDir(parentDir(desktop))
    writeFile(desktop, desktopEntry(config, slug,
      if hasIcon: slug else: ""))
    if hasIcon:
      installIcon(icon, bundle / "share" / "icons" / "hicolor" / "256x256" /
        "apps" / (slug & ".png"))
    let result = execCmdEx(quoteShellCommand([
      "tar", "-czf", output, "-C", staging, bundleName
    ]))
    if result.exitCode != 0:
      raise newException(OSError, "tar failed: " & result.output)
  finally:
    removeDir(staging)

proc buildDeb(binary, configPath: string; config: AppConfig; output: string) =
  let staging = getTempDir() / ("avelra-deb-" & $getCurrentProcessId())
  let root = staging / "root"
  removeDir(staging)
  createDir(root / "DEBIAN")
  try:
    let slug = slugify(config.name)
    copyExecutable(binary, root / "usr" / "bin" / slug)
    let icon = iconSource(configPath, config)
    let hasIcon = icon.len > 0
    let desktop = root / "usr" / "share" / "applications" /
      (slug & ".desktop")
    createDir(parentDir(desktop))
    writeFile(desktop, desktopEntry(config, slug,
      if hasIcon: slug else: ""))
    if hasIcon:
      installIcon(icon, root / "usr" / "share" / "icons" / "hicolor" /
        "256x256" / "apps" / (slug & ".png"))

    let architecture = block:
      let probe = execCmdEx("dpkg --print-architecture")
      if probe.exitCode == 0: probe.output.strip()
      else: "amd64"
    var control = "Package: " & slug & "\n" &
      "Version: " & config.version & "\n" &
      "Section: utils\n" &
      "Priority: optional\n" &
      "Architecture: " & architecture & "\n"
    if config.linuxDebDepends.len > 0:
      control.add("Depends: " & config.linuxDebDepends.join(", ") & "\n")
    control.add("Maintainer: " & debMaintainer(config) & "\n" &
      "Description: " & config.name & "\n")
    writeFile(root / "DEBIAN" / "control", control)

    let result = execCmdEx(quoteShellCommand([
      "dpkg-deb", "--build", root, output
    ]))
    if result.exitCode != 0:
      raise newException(OSError, "dpkg-deb failed: " & result.output)
  finally:
    removeDir(staging)

proc buildAppImage(binary, configPath: string; config: AppConfig; output: string) =
  let staging = getTempDir() / ("avelra-appimage-" & $getCurrentProcessId())
  let appDir = staging / "AppDir"
  let slug = slugify(config.name)
  removeDir(staging)
  createDir(appDir)
  try:
    copyExecutable(binary, appDir / "usr" / "bin" / slug)
    let icon = iconSource(configPath, config)
    let hasIcon = icon.len > 0
    writeFile(appDir / (slug & ".desktop"),
      desktopEntry(config, slug, if hasIcon: slug else: ""))
    if hasIcon:
      installIcon(icon, appDir / (slug & ".png"))
    let appRun = appDir / "AppRun"
    writeFile(appRun, "#!/bin/sh\n" &
      "HERE=\"$(dirname \"$(readlink -f \"$0\")\")\"\n" &
      "exec \"$HERE/usr/bin/" & slug & "\" \"$@\"\n")
    setFilePermissions(appRun, {
      fpUserRead, fpUserWrite, fpUserExec,
      fpGroupRead, fpGroupExec,
      fpOthersRead, fpOthersExec
    })
    let tool = findExe("appimagetool")
    if tool.len == 0:
      raise newException(OSError,
        "appimagetool not found; install it or use --target tar|deb")
    let result = execCmdEx(quoteShellCommand([tool, appDir, output]))
    if result.exitCode != 0:
      raise newException(OSError, "appimagetool failed: " & result.output)
  finally:
    removeDir(staging)

proc copyTree(source, destination: string) =
  ## Copies an extension tree while preserving executable bits.
  createDir(destination)
  for kind, path in walkDir(source):
    let target = destination / lastPathPart(path)
    case kind
    of pcDir:
      copyTree(path, target)
    of pcFile:
      copyFile(path, target)
      setFilePermissions(target, getFilePermissions(path))
    else:
      discard

proc copyAppPayload(appDir, destination: string; config: AppConfig) =
  createDir(destination)
  copyFile(appDir / "avelra.config.json",
    destination / "avelra.config.json")
  if config.extensions.len > 0:
    let extensions = appDir / "extensions"
    if not dirExists(extensions):
      raise newException(IOError, "extensions directory not found: " & extensions)
    copyTree(extensions, destination / "extensions")

proc defaultAppOutput(appDir: string; config: AppConfig;
                      target: InstallerTarget): string =
  let extension = case target
    of installerTar: ".tar.gz"
    of installerDeb: ".deb"
    of installerAppImage: ".AppImage"
  appDir / (slugify(config.name) & "-" & config.version & "-linux-x64" & extension)

proc writeLauncher(path, slug: string) =
  createDir(parentDir(path))
  writeFile(path, "#!/bin/sh\n" &
    "exec /usr/lib/" & slug & "/" & slug &
    " --config /usr/lib/" & slug & "/avelra.config.json \"$@\"\n")
  setFilePermissions(path, {
    fpUserRead, fpUserWrite, fpUserExec,
    fpGroupRead, fpGroupExec,
    fpOthersRead, fpOthersExec
  })

proc buildAppTar(appDir, configPath: string; config: AppConfig; output: string) =
  let staging = getTempDir() / ("avelra-app-tar-" & $getCurrentProcessId())
  let slug = slugify(config.name)
  let bundleName = slug & "-" & config.version
  let bundle = staging / bundleName
  removeDir(staging)
  createDir(bundle / "bin")
  try:
    copyExecutable(appDir / "bin" / slug, bundle / "bin" / slug)
    copyAppPayload(appDir, bundle, config)
    let icon = iconSource(configPath, config)
    let hasIcon = icon.len > 0
    let desktop = bundle / "share" / "applications" /
      (slug & ".desktop")
    createDir(parentDir(desktop))
    writeFile(desktop, desktopEntry(config, slug,
      if hasIcon: slug else: ""))
    if hasIcon:
      installIcon(icon, bundle / "share" / "icons" / "hicolor" / "256x256" /
        "apps" / (slug & ".png"))
    let result = execCmdEx(quoteShellCommand([
      "tar", "-czf", output, "-C", staging, bundleName
    ]))
    if result.exitCode != 0:
      raise newException(OSError, "tar failed: " & result.output)
  finally:
    removeDir(staging)

proc buildAppDeb(appDir, configPath: string; config: AppConfig; output: string) =
  let staging = getTempDir() / ("avelra-app-deb-" & $getCurrentProcessId())
  let root = staging / "root"
  let slug = slugify(config.name)
  removeDir(staging)
  createDir(root / "DEBIAN")
  try:
    let appRoot = root / "usr" / "lib" / slug
    copyExecutable(appDir / "bin" / slug, appRoot / slug)
    copyAppPayload(appDir, appRoot, config)
    writeLauncher(root / "usr" / "bin" / slug, slug)

    let icon = iconSource(configPath, config)
    let hasIcon = icon.len > 0
    let desktop = root / "usr" / "share" / "applications" /
      (slug & ".desktop")
    createDir(parentDir(desktop))
    writeFile(desktop, desktopEntry(config, slug,
      if hasIcon: slug else: ""))
    if hasIcon:
      installIcon(icon, root / "usr" / "share" / "icons" / "hicolor" /
        "256x256" / "apps" / (slug & ".png"))

    let architecture = block:
      let probe = execCmdEx("dpkg --print-architecture")
      if probe.exitCode == 0: probe.output.strip()
      else: "amd64"
    var control = "Package: " & slug & "\n" &
      "Version: " & config.version & "\n" &
      "Section: utils\n" &
      "Priority: optional\n" &
      "Architecture: " & architecture & "\n"
    if config.linuxDebDepends.len > 0:
      control.add("Depends: " & config.linuxDebDepends.join(", ") & "\n")
    control.add("Maintainer: " & debMaintainer(config) & "\n" &
      "Description: " & config.name & "\n")
    writeFile(root / "DEBIAN" / "control", control)

    let result = execCmdEx(quoteShellCommand(["dpkg-deb", "--build", root, output]))
    if result.exitCode != 0:
      raise newException(OSError, "dpkg-deb failed: " & result.output)
  finally:
    removeDir(staging)

proc buildAppImageFromDir(appDir, configPath: string; config: AppConfig; output: string) =
  let staging = getTempDir() / ("avelra-app-appimage-" & $getCurrentProcessId())
  let appImageDir = staging / "AppDir"
  let slug = slugify(config.name)
  removeDir(staging)
  createDir(appImageDir)
  try:
    copyExecutable(appDir / "bin" / slug, appImageDir / "usr" / "bin" / slug)
    copyAppPayload(appDir, appImageDir / "usr" / "lib" / slug, config)
    let icon = iconSource(configPath, config)
    let hasIcon = icon.len > 0
    writeFile(appImageDir / (slug & ".desktop"),
      desktopEntry(config, slug, if hasIcon: slug else: ""))
    if hasIcon:
      installIcon(icon, appImageDir / (slug & ".png"))
    let appRun = appImageDir / "AppRun"
    writeFile(appRun, "#!/bin/sh\n" &
      "HERE=\"$(dirname \"$(readlink -f \"$0\")\")\"\n" &
      "exec \"$HERE/usr/bin/" & slug & "\" --config \"$HERE/usr/lib/" &
      slug & "/avelra.config.json\" \"$@\"\n")
    setFilePermissions(appRun, {
      fpUserRead, fpUserWrite, fpUserExec,
      fpGroupRead, fpGroupExec,
      fpOthersRead, fpOthersExec
    })
    let tool = findExe("appimagetool")
    if tool.len == 0:
      raise newException(OSError,
        "appimagetool not found; install it or use --target tar|deb")
    let result = execCmdEx(quoteShellCommand([tool, appImageDir, output]))
    if result.exitCode != 0:
      raise newException(OSError, "appimagetool failed: " & result.output)
  finally:
    removeDir(staging)

proc buildAppInstaller*(appDir: string; target: InstallerTarget;
                        output = ""): string =
  ## Builds an installer from an extension-aware build directory.
  let root = absolutePath(appDir)
  let configPath = root / "avelra.config.json"
  if not fileExists(configPath):
    raise newException(IOError, "config not found: " & configPath)
  let config = loadConfig(configPath)
  validateIdentifier(config.identifier)
  let slug = slugify(config.name)
  let binary = root / "bin" / slug
  if not fileExists(binary):
    raise newException(IOError, "binary not found: " & binary)
  result = if output.len > 0: absolutePath(output)
           else: defaultAppOutput(root, config, target)
  createDir(parentDir(result))
  case target
  of installerTar: buildAppTar(root, configPath, config, result)
  of installerDeb: buildAppDeb(root, configPath, config, result)
  of installerAppImage: buildAppImageFromDir(root, configPath, config, result)
  echo "created ", result

proc buildInstaller*(binary, configPath: string; target: InstallerTarget;
                     output = ""): string =
  ## Builds a host-native Linux installer and returns its path.
  let binaryPath = absolutePath(binary)
  if not fileExists(binaryPath):
    raise newException(IOError, "binary not found: " & binaryPath)
  let config = loadConfig(configPath)
  validateIdentifier(config.identifier)
  if config.version.len == 0 or config.version.contains({'/', ' '}):
    raise newException(ValueError, "invalid version: " & config.version)

  result = if output.len > 0: absolutePath(output)
           else: defaultOutput(configPath, config, target)
  createDir(parentDir(result))
  case target
  of installerTar: buildTar(binaryPath, configPath, config, result)
  of installerDeb: buildDeb(binaryPath, configPath, config, result)
  of installerAppImage: buildAppImage(binaryPath, configPath, config, result)
  echo "created ", result
