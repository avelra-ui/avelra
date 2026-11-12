## Project initialization tests.

import std/[os, osproc, strutils, unittest]

import cli/project
import support

let root = getTempDir() / ("avelra-cli-init-" & $getCurrentProcessId())
let templateDirPath = getCurrentDir() / "share" / "avelra" / "templates" / "app"
removeDir(root)
createDir(root)

try:
  suite "CLI init":
    test "creates a project from the template":
      let app = root / "demo"
      let configPath = initProject(app, templateDirPath)
      check fileExists(app / "client" / "index.html")
      check fileExists(app / "client" / "app.js")
      check fileExists(app / "client" / "avelra-lockup.svg")
      check fileExists(app / "icon.png")
      check readFile(app / "client" / "index.html").contains("brand-lockup")
      check readFile(app / "client" / "index.html").contains("avelra-lockup.svg")
      check readFile(app / "client" / "index.html").contains("~0.5 MiB runtime")
      check readFile(app / "client" / "index.html").contains("https://avelra.dev/docs/")
      check readFile(app / "client" / "index.html").contains("https://github.com/avelra-ui/avelra")
      check readFile(app / "client" / "index.html").contains("data-external")
      check readFile(app / "client" / "app.js").contains("os.openExternal")
      check fileExists(configPath)
      check readFile(configPath).contains("\"name\": \"demo\"")

    test "refuses a non-empty destination":
      let app = root / "busy"
      createDir(app)
      writeFile(app / "keep.txt", "keep")
      expect IOError:
        discard initProject(app, templateDirPath)
      check fileExists(app / "keep.txt")

    test "force replaces a non-empty destination":
      let app = root / "force"
      createDir(app)
      writeFile(app / "old.txt", "old")
      discard initProject(app, templateDirPath, force = true)
      check not fileExists(app / "old.txt")
      check fileExists(app / "client" / "index.html")

    test "the CLI init command works":
      let app = root / "cli-app"
      let result = execCmdEx(cliPath() & " init " & app)
      check result.exitCode == 0
      check fileExists(app / "avelra.config.json")
      check fileExists(app / "client" / "index.html")
finally:
  removeDir(root)
