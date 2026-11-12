## Public configuration for a Avelra desktop project.

import std/[json, os, strutils, tables]

type
  WindowConfig* = object
    title*: string
    width*: int
    height*: int

  ExtensionConfig* = object
    id*: string
    protocol*: int
    autoStart*: bool
    requestTimeoutMs*: int
    commands*: Table[string, seq[string]]

  AppConfig* = object
    name*: string
    version*: string
    identifier*: string
    client*: string
    icon*: string
    linuxDebDepends*: seq[string]
    window*: WindowConfig
    extensions*: seq[ExtensionConfig]

const defaultLinuxDebDepends* = [
  "libgtk-3-0t64 | libgtk-3-0",
  "libwebkit2gtk-4.1-0"
]

proc slugify*(value: string): string =
  ## Stable lowercase identifier used for package/output directories.
  var previousDash = false
  for ch in value.toLowerAscii():
    if ch in {'a' .. 'z', '0' .. '9'}:
      result.add ch
      previousDash = false
    elif not previousDash:
      result.add '-'
      previousDash = true
  result = result.strip(chars = {'-'})
  if result.len == 0:
    result = "app"

proc defaultConfig*(name = "my-app"): AppConfig =
  AppConfig(
    name: name,
    version: "0.1.0",
    identifier: "com.example." & slugify(name),
    client: "client",
    icon: "",
    linuxDebDepends: @defaultLinuxDebDepends,
    window: WindowConfig(title: name, width: 600, height: 400),
    extensions: @[]
  )

proc requiredString(obj: JsonNode; key: string): string =
  if not obj.hasKey(key) or obj[key].kind != JString:
    raise newException(ValueError, "config field '" & key & "' must be a string")
  result = obj[key].getStr()
  if result.len == 0:
    raise newException(ValueError, "config field '" & key & "' is empty")

proc optionalString(obj: JsonNode; key, fallback: string): string =
  if not obj.hasKey(key):
    return fallback
  if obj[key].kind != JString:
    raise newException(ValueError, "config field '" & key & "' must be a string")
  obj[key].getStr()

proc hostOs*(): string =
  ## The manifest OS key used for the current build.
  when defined(linux):
    "linux"
  elif defined(windows):
    "windows"
  elif defined(macosx):
    "macos"
  else:
    "linux"

proc validateExtensionId*(id: string) =
  if id.len == 0 or id[0] notin {'a' .. 'z'}:
    raise newException(ValueError, "extension id must start with a-z")
  for ch in id:
    if ch notin {'a' .. 'z', '0' .. '9', '-'}:
      raise newException(ValueError,
        "extension id contains unsupported characters: " & id)

proc optionalInt(obj: JsonNode; key: string; fallback: int): int =
  if not obj.hasKey(key):
    return fallback
  if obj[key].kind != JInt:
    raise newException(ValueError, "config field '" & key & "' must be an integer")
  obj[key].getInt()

proc optionalBool(obj: JsonNode; key: string; fallback: bool): bool =
  if not obj.hasKey(key):
    return fallback
  if obj[key].kind != JBool:
    raise newException(ValueError, "config field '" & key & "' must be a boolean")
  obj[key].getBool()

proc isWithin(path, root: string): bool =
  let normalizedRoot = normalizedPath(absolutePath(root))
  let normalizedValue = normalizedPath(absolutePath(path))
  normalizedValue == normalizedRoot or
    normalizedValue.startsWith(normalizedRoot & $DirSep)

proc validateCommandPath(command: seq[string]; appDir: string) =
  let executable = command[0]
  if executable.len == 0:
    raise newException(ValueError, "extension command must not be empty")
  if executable.contains({'/', '\\'}) or executable.startsWith("."):
    let resolved = if isAbsolute(executable): executable else: appDir / executable
    if not isWithin(resolved, appDir):
      raise newException(ValueError,
        "extension command escapes the app directory: " & executable)

proc parseExtension(node: JsonNode; appDir: string): ExtensionConfig =
  if node.kind != JObject:
    raise newException(ValueError, "extension entries must be objects")

  result.id = requiredString(node, "id")
  validateExtensionId(result.id)
  result.protocol = optionalInt(node, "protocol", 1)
  if result.protocol <= 0:
    raise newException(ValueError, "extension protocol must be positive")
  result.autoStart = optionalBool(node, "autoStart", false)
  result.requestTimeoutMs = optionalInt(node, "requestTimeoutMs", 30000)
  if result.requestTimeoutMs < 0:
    raise newException(ValueError, "requestTimeoutMs must be >= 0")

  if not node.hasKey("command") or node["command"].kind != JObject:
    raise newException(ValueError,
      "extension '" & result.id & "' requires a command object")
  for osName, value in node["command"]:
    if osName notin ["linux", "windows", "macos"]:
      raise newException(ValueError,
        "extension '" & result.id & "' has unknown OS: " & osName)
    if value.kind != JArray or value.len == 0:
      raise newException(ValueError,
        "extension '" & result.id & "' command must be a non-empty array")
    var command: seq[string]
    for part in value:
      if part.kind != JString or part.getStr().len == 0:
        raise newException(ValueError,
          "extension '" & result.id & "' command entries must be non-empty strings")
      command.add part.getStr()
    result.commands[osName] = command

  if result.commands.len == 0:
    raise newException(ValueError,
      "extension '" & result.id & "' has no commands")

  let currentOs = hostOs()
  if result.commands.hasKey(currentOs):
    validateCommandPath(result.commands[currentOs], appDir)

proc commandFor*(extension: ExtensionConfig; osName = hostOs()): seq[string] =
  ## Returns the argv for the requested OS or raises `extension_unavailable`.
  if not extension.commands.hasKey(osName):
    raise newException(ValueError,
      "extension '" & extension.id & "' has no command for " & osName)
  result = extension.commands[osName]

proc loadConfig*(path: string): AppConfig =
  ## Reads `avelra.config.json` and validates the required fields.
  if not fileExists(path):
    raise newException(IOError, "config not found: " & path)

  var node: JsonNode
  try:
    node = parseFile(path)
  except JsonParsingError as exc:
    raise newException(ValueError, "invalid config: " & exc.msg)

  if node.kind != JObject:
    raise newException(ValueError, "config root must be a JSON object")

  result.name = requiredString(node, "name")
  result.version = optionalString(node, "version", "0.1.0")
  result.identifier = optionalString(
    node, "identifier", "com.example." & slugify(result.name)
  )
  result.client = optionalString(node, "client", "client")
  result.icon = optionalString(node, "icon", "")

  result.linuxDebDepends = @defaultLinuxDebDepends
  if node.hasKey("linuxDebDepends"):
    if node["linuxDebDepends"].kind != JArray:
      raise newException(ValueError,
        "config field 'linuxDebDepends' must be an array")
    result.linuxDebDepends = @[]
    for item in node["linuxDebDepends"]:
      if item.kind != JString or item.getStr().len == 0:
        raise newException(ValueError,
          "linuxDebDepends entries must be non-empty strings")
      let dependency = item.getStr()
      for ch in dependency:
        if ch notin {'a' .. 'z', '0' .. '9', '+', '-', '.', ':', '|', ' '}:
          raise newException(ValueError,
            "invalid Debian dependency: " & dependency)
      result.linuxDebDepends.add dependency

  if node.hasKey("window"):
    if node["window"].kind != JObject:
      raise newException(ValueError, "config field 'window' must be an object")
    let window = node["window"]
    result.window.title = optionalString(window, "title", result.name)
    result.window.width = if window.hasKey("width"): window["width"].getInt()
                         else: 600
    result.window.height = if window.hasKey("height"): window["height"].getInt()
                          else: 400
  else:
    result.window = WindowConfig(title: result.name, width: 600, height: 400)

  if result.window.width <= 0 or result.window.height <= 0:
    raise newException(ValueError, "window width and height must be positive")

  let appDir = parentDir(absolutePath(path))
  if node.hasKey("extensions"):
    if node["extensions"].kind != JArray:
      raise newException(ValueError, "config field 'extensions' must be an array")
    var seen: seq[string]
    for item in node["extensions"]:
      let extension = parseExtension(item, appDir)
      if extension.id in seen:
        raise newException(ValueError, "duplicate extension id: " & extension.id)
      seen.add extension.id
      result.extensions.add extension

proc saveConfig*(path: string; config: AppConfig) =
  var extensions = newJArray()
  for extension in config.extensions:
    var commands = newJObject()
    for osName, command in extension.commands:
      commands[osName] = %command
    extensions.add(%*{
      "id": extension.id,
      "protocol": extension.protocol,
      "autoStart": extension.autoStart,
      "requestTimeoutMs": extension.requestTimeoutMs,
      "command": commands
    })

  let node = %*{
    "name": config.name,
    "version": config.version,
    "identifier": config.identifier,
    "client": config.client,
    "icon": config.icon,
    "linuxDebDepends": config.linuxDebDepends,
    "window": {
      "title": config.window.title,
      "width": config.window.width,
      "height": config.window.height
    },
    "extensions": extensions
  }
  writeFile(path, node.pretty & "\n")

proc projectDir*(configPath: string): string =
  parentDir(absolutePath(configPath))

proc clientDir*(configPath: string; config: AppConfig): string =
  if isAbsolute(config.client):
    config.client
  else:
    projectDir(configPath) / config.client
