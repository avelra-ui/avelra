## CLI config parsing tests.

import std/[os, unittest]

import cli/config

let root = getTempDir() / ("avelra-cli-config-" & $getCurrentProcessId())
removeDir(root)
createDir(root)

try:
  suite "CLI config":
    test "slugify produces stable output names":
      check slugify("My App!") == "my-app"
      check slugify("  ") == "app"

    test "defaults are valid":
      let config = defaultConfig("Demo")
      check config.name == "Demo"
      check config.identifier == "com.example.demo"
      check config.client == "client"
      check config.window.width == 600

    test "save and load round-trip":
      let path = root / "avelra.config.json"
      var config = defaultConfig("Demo App")
      config.version = "1.2.3"
      config.icon = "icons/app.png"
      config.linuxDebDepends = @["zenity", "libgtk-3-0"]
      config.window.width = 800
      saveConfig(path, config)
      let loaded = loadConfig(path)
      check loaded.name == "Demo App"
      check loaded.version == "1.2.3"
      check loaded.icon == "icons/app.png"
      check loaded.linuxDebDepends == @["zenity", "libgtk-3-0"]
      check loaded.window.width == 800
      check clientDir(path, loaded) == root / "client"

    test "missing name is rejected":
      let path = root / "bad.json"
      writeFile(path, """{"client":"client"}""")
      expect ValueError:
        discard loadConfig(path)

    test "invalid deb dependency is rejected":
      let path = root / "bad-dep.json"
      writeFile(path, """{"name":"Demo","linuxDebDepends":["zenity; rm -rf /"]}""")
      expect ValueError:
        discard loadConfig(path)

    test "non-object root is rejected":
      let path = root / "array.json"
      writeFile(path, "[]")
      expect ValueError:
        discard loadConfig(path)
finally:
  removeDir(root)
