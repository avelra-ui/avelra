## Linux installer builder tests.

import std/[os, osproc, strutils, tables, unittest]

import cli/config
import installer/linux

let root = getTempDir() / ("avelra-installer-test-" & $getCurrentProcessId())
removeDir(root)
createDir(root)
let binary = root / "app"
let icon = root / "icon.png"
let configPath = root / "avelra.config.json"
copyFile("/bin/true", binary)
writeFile(icon, "png")
var appConfig = defaultConfig("Demo App")
appConfig.version = "1.2.3"
appConfig.icon = "icon.png"
appConfig.linuxDebDepends = @["zenity"]
appConfig.identifier = "com.example.demo"
saveConfig(configPath, appConfig)

try:
  suite "installer":
    test "tar contains binary and desktop entry":
      let output = root / "demo.tar.gz"
      discard buildInstaller(binary, configPath, installerTar, output)
      check fileExists(output)
      let listing = execCmdEx("tar -tzf " & output).output
      check listing.contains("app")
      check listing.contains("share/applications/com.example.demo.desktop")
      check listing.contains("share/icons/hicolor/256x256/apps/com.example.demo.png")

    test "deb has the expected control metadata":
      if findExe("dpkg-deb").len == 0:
        check true
      else:
        let output = root / "demo.deb"
        discard buildInstaller(binary, configPath, installerDeb, output)
        check fileExists(output)
        let info = execCmdEx("dpkg-deb -I " & output).output
        check info.contains("Package: demo-app")
        check info.contains("Version: 1.2.3")
        check info.contains("Architecture: amd64")
        check info.contains("Depends: zenity")

    test "default app-dir deb declares GTK/WebKit runtime deps":
      if findExe("dpkg-deb").len == 0:
        check true
      else:
        let appDir = root / "appdir-default-deps"
        createDir(appDir / "bin")
        copyFile("/bin/true", appDir / "bin" / "demo-app")
        var appConfig = defaultConfig("Demo App")
        appConfig.identifier = "com.example.demo"
        saveConfig(appDir / "avelra.config.json", appConfig)
        let output = root / "appdir-default-deps.deb"
        discard buildAppInstaller(appDir, installerDeb, output)
        let info = execCmdEx("dpkg-deb -I " & output).output
        check info.contains("libgtk-3-0t64 | libgtk-3-0")
        check info.contains("libwebkit2gtk-4.1-0")

    test "app-dir appimage reports a missing appimagetool":
      let appDir = root / "appdir-appimage"
      createDir(appDir / "bin")
      copyFile("/bin/true", appDir / "bin" / "demo-app")
      var appConfig = defaultConfig("Demo App")
      appConfig.identifier = "com.example.demo"
      saveConfig(appDir / "avelra.config.json", appConfig)
      if findExe("appimagetool").len == 0:
        expect OSError:
          discard buildAppInstaller(appDir, installerAppImage,
            root / "appdir.AppImage")
      else:
        check true

    test "appimage reports a missing appimagetool":
      if findExe("appimagetool").len == 0:
        expect OSError:
          discard buildInstaller(binary, configPath, installerAppImage,
            root / "demo.AppImage")
      else:
        check true

    test "app-dir tar includes runtime, config and extensions":
      let appDir = root / "appdir"
      createDir(appDir / "bin")
      createDir(appDir / "extensions" / "echo")
      copyFile("/bin/true", appDir / "bin" / "demo-app")
      copyFile("/bin/true", appDir / "extensions" / "echo" / "echo")
      var appConfig = defaultConfig("Demo App")
      appConfig.version = "1.2.3"
      appConfig.identifier = "com.example.demo"
      appConfig.extensions = @[ExtensionConfig(
        id: "echo",
        protocol: 1,
        commands: {"linux": @["extensions/echo/echo"]}.toTable
      )]
      saveConfig(appDir / "avelra.config.json", appConfig)
      let output = root / "appdir.tar.gz"
      discard buildAppInstaller(appDir, installerTar, output)
      let listing = execCmdEx("tar -tzf " & output).output
      check listing.contains("bin/demo-app")
      check listing.contains("avelra.config.json")
      check listing.contains("extensions/echo/echo")

    test "app-dir deb uses /usr/lib and launcher":
      let appDir = root / "appdir-deb"
      createDir(appDir / "bin")
      copyFile("/bin/true", appDir / "bin" / "demo-app")
      var appConfig = defaultConfig("Demo App")
      appConfig.version = "1.2.3"
      appConfig.identifier = "com.example.demo"
      saveConfig(appDir / "avelra.config.json", appConfig)
      let output = root / "appdir.deb"
      discard buildAppInstaller(appDir, installerDeb, output)
      let listing = execCmdEx("dpkg-deb -c " & output).output
      check listing.contains("./usr/lib/demo-app/demo-app")
      check listing.contains("./usr/bin/demo-app")
      check listing.contains("./usr/lib/demo-app/avelra.config.json")

    test "missing binary is rejected":
      expect IOError:
        discard buildInstaller(root / "missing", configPath, installerTar)

    test "unsafe identifier is rejected":
      var bad = appConfig
      bad.identifier = "../escape"
      let badPath = root / "bad.json"
      saveConfig(badPath, bad)
      expect ValueError:
        discard buildInstaller(binary, badPath, installerTar)
finally:
  removeDir(root)
