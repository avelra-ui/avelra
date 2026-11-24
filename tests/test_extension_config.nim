## Extension manifest parsing and validation tests.

import std/[os, strutils, unittest]

import cli/config

let root = getTempDir() / ("avelra-extension-config-" & $getCurrentProcessId())
removeDir(root)
createDir(root / "extensions" / "uploader")
writeFile(root / "extensions" / "uploader" / "uploader", "")
let configPath = root / "avelra.config.json"

proc validConfig(id = "uploader"; osName = "";
                 command = "extensions/uploader/uploader"): string =
  let selectedOs = if osName.len == 0: hostOs() else: osName
  result = """{
    "name": "Extension App",
    "extensions": [
      {
        "id": "__id__",
        "protocol": 1,
        "autoStart": true,
        "requestTimeoutMs": 0,
        "command": {
          "__os__": ["__cmd__"]
        }
      }
    ]
  }"""
  result = result.replace("__id__", id)
  result = result.replace("__os__", selectedOs)
  result = result.replace("__cmd__", command)

try:
  suite "extension manifest":
    test "parses fields and selects the host command":
      writeFile(configPath, validConfig())
      let config = loadConfig(configPath)
      check config.extensions.len == 1
      let extension = config.extensions[0]
      check extension.id == "uploader"
      check extension.protocol == 1
      check extension.autoStart
      check extension.requestTimeoutMs == 0
      check commandFor(extension) == @["extensions/uploader/uploader"]

    test "save/load round-trips extensions":
      writeFile(configPath, validConfig())
      let config = loadConfig(configPath)
      saveConfig(configPath, config)
      let loaded = loadConfig(configPath)
      check loaded.extensions.len == 1
      check loaded.extensions[0].id == "uploader"
      check loaded.extensions[0].autoStart
      check loaded.extensions[0].requestTimeoutMs == 0
      check commandFor(loaded.extensions[0]) == @["extensions/uploader/uploader"]

    test "duplicate ids are rejected":
      let duplicate = """{
        "name": "Duplicate",
        "extensions": [
          {"id":"uploader","command":{"linux":["extensions/uploader/uploader"]}},
          {"id":"uploader","command":{"linux":["extensions/uploader/uploader"]}}
        ]
      }"""
      writeFile(configPath, duplicate)
      expect ValueError:
        discard loadConfig(configPath)

    test "invalid ids are rejected":
      writeFile(configPath, validConfig(id = "Uploader"))
      expect ValueError:
        discard loadConfig(configPath)

    test "unknown OS is rejected":
      writeFile(configPath, validConfig(osName = "plan9"))
      expect ValueError:
        discard loadConfig(configPath)

    test "commands escaping the app directory are rejected":
      writeFile(configPath, validConfig(command = "../uploader"))
      expect ValueError:
        discard loadConfig(configPath)

    test "missing host command is explicit":
      writeFile(configPath, validConfig(osName = "windows"))
      let config = loadConfig(configPath)
      if hostOs() != "windows":
        expect ValueError:
          discard commandFor(config.extensions[0])

    test "missing command object is rejected":
      writeFile(configPath,
        """{"name":"No command","extensions":[{"id":"uploader"}]}""")
      expect ValueError:
        discard loadConfig(configPath)

    test "empty command array is rejected":
      writeFile(configPath, """{
        "name": "Empty command",
        "extensions": [{"id":"uploader","command":{"linux":[]}}]
      }""")
      expect ValueError:
        discard loadConfig(configPath)
finally:
  removeDir(root)
