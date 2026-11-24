## CLI build integration tests.

import std/[json, options, os, osproc, unittest]

import adapters/archive/[payload, zip_store]
import cli/config
import cli/project
import support

let root = getTempDir() / ("avelra-cli-build-" & $getCurrentProcessId())
let templateDirPath = getCurrentDir() / "share" / "avelra" / "templates" / "app"
removeDir(root)
createDir(root)

try:
  suite "CLI build":
    test "builds a single executable in dist":
      let app = root / "demo"
      let configPath = initProject(app, templateDirPath)
      let result = execCmdEx(cliPath() & " --config " & configPath & " build")
      check result.exitCode == 0
      let binaryName = when defined(windows): "demo.exe" else: "demo"
      let binary = app / "dist" / "demo" / binaryName
      check fileExists(binary)
      check getFileSize(binary) > 1000

    test "embeds window config in the single executable":
      let app = root / "embedded"
      let configPath = initProject(app, templateDirPath)
      let result = execCmdEx(cliPath() & " --config " & configPath & " build")
      check result.exitCode == 0

      let embeddedName = when defined(windows): "embedded.exe" else: "embedded"
      let binary = app / "dist" / "embedded" / embeddedName
      let footer = readPayloadFooter(binary)
      check footer.isSome
      let info = footer.get
      let data = readFile(binary)
      let archive = data[int(info.offset) ..< int(info.offset + info.length)]
      let embedded = readZipEntry(archive, ".avelra/config.json")
      check embedded.isSome
      let embeddedIcon = readZipEntry(archive, ".avelra/icon.png")
      check embeddedIcon.isSome
      check embeddedIcon.get().len > 0
      let node = parseJson(embedded.get)
      check node["window"]["title"].getStr() == "embedded"
      check node["window"]["width"].getInt() == 960
      check node["window"]["height"].getInt() == 600

    test "builds an extension-aware app directory":
      let app = root / "with-extension"
      let configPath = initProject(app, templateDirPath)
      createDir(app / "extensions" / "echo")
      let fixtureExt = when defined(windows): ".exe" else: ""
      let echoName = "echo" & fixtureExt
      copyFile(testBin("extension_echo" & fixtureExt),
        app / "extensions" / "echo" / echoName)
      writeFile(app / "extensions" / "echo" / "echo.nim", "source must not ship")
      var config = parseFile(configPath)
      var command = newJObject()
      command[hostOs()] = %*["extensions/echo/" & echoName]
      config["extensions"] = %*[{
        "id": "echo",
        "protocol": 1,
        "command": command
      }]
      writeFile(configPath, config.pretty & "\n")
      let result = execCmdEx(cliPath() & " --config " & configPath & " build")
      check result.exitCode == 0
      let extName = when defined(windows): "with-extension.exe" else: "with-extension"
      check fileExists(app / "dist" / "with-extension" / "bin" / extName)
      check fileExists(app / "dist" / "with-extension" / "avelra.config.json")
      check fileExists(app / "dist" / "with-extension" / "extensions" / "echo" / echoName)
      check not fileExists(app / "dist" / "with-extension" / "extensions" / "echo" / "echo.nim")

    test "fails when client is missing":
      let app = root / "broken"
      let configPath = initProject(app, templateDirPath)
      removeDir(app / "client")
      let result = execCmdEx(cliPath() & " --config " & configPath & " build")
      check result.exitCode != 0
finally:
  removeDir(root)
