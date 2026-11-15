## Avelra — composition root.
##
## Selects the platform window adapter at compile time, starts the local static
## server for `client/`, and wires everything to the application dispatcher.

import std/[json, monotimes, os, strutils, times]

import adapters/http/[resource_store, static_server]
import adapters/system/[env, url_open]
import avelra_version
import application/dispatcher
import ports/[health_port, quit_port]
import application/handlers/[app_handlers, os_handlers]
import cli/config
import extensions/manager
import ports/extension_port

when defined(linux):
  import adapters/linux/app_window as platform_window
elif defined(windows) or defined(macosx):
  # Experimental platforms use the cross-platform webview adapter for now.
  import adapters/webview/generic_window as platform_window
else:
  {.error: "Unsupported platform: expected linux, windows, or macosx".}

type
  RuntimeOptions = object
    client: string
    title: string
    width: int
    height: int
    config: string
    icon: string
    titleSet: bool
    iconSet: bool
    widthSet: bool
    heightSet: bool

proc parseRuntimeOptions(): RuntimeOptions =
  result = RuntimeOptions(
    client: "client",
    title: "Hello Avelra",
    width: 600,
    height: 400,
    config: ""
  )
  let args = commandLineParams()
  var index = 0
  while index < args.len:
    case args[index]
    of "--client":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--client requires a path")
      result.client = args[index]
    of "--title":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--title requires a value")
      result.title = args[index]
      result.titleSet = true
    of "--config":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--config requires a path")
      result.config = args[index]
    of "--icon":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--icon requires a path")
      result.icon = args[index]
      result.iconSet = true
    of "--width":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--width requires a value")
      try:
        result.width = parseInt(args[index])
        result.widthSet = true
      except ValueError:
        raise newException(ValueError, "--width must be an integer")
    of "--height":
      inc index
      if index >= args.len:
        raise newException(ValueError, "--height requires a value")
      try:
        result.height = parseInt(args[index])
        result.heightSet = true
      except ValueError:
        raise newException(ValueError, "--height must be an integer")
    else:
      raise newException(ValueError, "unknown runtime option: " & args[index])
    inc index

  if result.client.len == 0:
    raise newException(ValueError, "--client must not be empty")
  if result.width <= 0 or result.height <= 0:
    raise newException(ValueError, "window size must be positive")

proc applyWindowConfig(options: var RuntimeOptions; appConfig: AppConfig;
                       configPath: string) =
  ## Applies config window values unless the CLI passed them explicitly.
  if not options.titleSet:
    options.title = appConfig.window.title
  if not options.widthSet:
    options.width = appConfig.window.width
  if not options.heightSet:
    options.height = appConfig.window.height
  if not options.iconSet and appConfig.icon.len > 0:
    options.icon = if isAbsolute(appConfig.icon): appConfig.icon
                   else: projectDir(absolutePath(configPath)) / appConfig.icon
    options.iconSet = true

proc applyEmbeddedWindowConfig(options: var RuntimeOptions; node: JsonNode) =
  ## Applies window metadata from the single-executable payload.
  if node.kind != JObject:
    raise newException(ValueError, "embedded config root must be an object")
  if not node.hasKey("window") or node["window"].kind != JObject:
    return
  let window = node["window"]
  if not options.titleSet and window.hasKey("title") and
      window["title"].kind == JString:
    options.title = window["title"].getStr()
  if not options.widthSet and window.hasKey("width") and
      window["width"].kind == JInt:
    options.width = window["width"].getInt()
  if not options.heightSet and window.hasKey("height") and
      window["height"].kind == JInt:
    options.height = window["height"].getInt()

proc findRuntimeConfig(explicitPath: string): string =
  ## Explicit --config wins; otherwise look next to the binary and one level up
  ## (tar layout: bin/<app> + ../avelra.config.json).
  if explicitPath.len > 0:
    return absolutePath(explicitPath)
  let exeDir = getAppDir()
  for candidate in [
    exeDir / "avelra.config.json",
    parentDir(exeDir) / "avelra.config.json"
  ]:
    if fileExists(candidate):
      return absolutePath(candidate)
  ""

proc platformArchitecture(): string =
  when defined(amd64): "amd64"
  elif defined(arm64): "arm64"
  elif defined(i386): "386"
  else: "unknown"

proc platformWebview(): string =
  when defined(linux): "webkitgtk-4.1"
  elif defined(macosx): "wkwebview"
  elif defined(windows): "webview2"
  else: "unknown"

when isMainModule:
  try:
    let startedAt = now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    let startedMono = getMonoTime()
    var options = parseRuntimeOptions()
    var manager: ExtensionManager
    var extensionPort: ExtensionPort
    var iconTemp = ""
    var appName = "unknown"
    var appVersion = "unknown"
    var appIdentifier = "unknown"
    var configLoaded = false
    let configPath = findRuntimeConfig(options.config)
    if configPath.len > 0:
      let appConfig = loadConfig(configPath)
      appName = appConfig.name
      appVersion = appConfig.version
      appIdentifier = appConfig.identifier
      configLoaded = true
      applyWindowConfig(options, appConfig, configPath)
      manager = newExtensionManager(appConfig.extensions, projectDir(configPath))
      extensionPort = manager.extensionPort()

    let store = openResourceStore(getAppFilename(), options.client)
    if configPath.len == 0:
      let embedded = store.get(".avelra/config.json")
      if embedded.found:
        let embeddedConfig = parseJson(embedded.resource.data)
        appName = embeddedConfig{"name"}.getStr("unknown")
        appVersion = embeddedConfig{"version"}.getStr("unknown")
        appIdentifier = embeddedConfig{"identifier"}.getStr("unknown")
        configLoaded = true
        applyEmbeddedWindowConfig(options, embeddedConfig)
      if not options.iconSet:
        let embeddedIcon = store.get(".avelra/icon.png")
        if embeddedIcon.found:
          iconTemp = getTempDir() / ("avelra-icon-" & $getCurrentProcessId() & ".png")
          writeFile(iconTemp, embeddedIcon.resource.data)
          options.icon = iconTemp
          options.iconSet = true

    let server = startStaticServer(store)
    let health = HealthPort(
      snapshot: proc(): HealthSnapshot =
        var checks: seq[HealthCheck]
        checks.add HealthCheck(
          id: "config",
          status: if configLoaded: hsOk else: hsFailed,
          message: if configLoaded: "" else: "application config was not loaded")
        let assets = store.get(IndexFile)
        checks.add HealthCheck(
          id: "client-assets",
          status: if assets.found: hsOk else: hsFailed,
          message: if assets.found: "" else: "client/index.html is not readable")
        checks.add HealthCheck(
          id: "static-server",
          status: if server.isRunning: hsOk else: hsFailed,
          message: if server.isRunning: "" else: "local static server is not running")
        var extensions: seq[HealthExtension]
        var extensionCount = 0
        if manager != nil:
          extensions = manager.health()
          for extension in extensions:
            if extension.status == "failed" or extension.status == "starting":
              inc extensionCount
        checks.add HealthCheck(
          id: "extensions",
          status: if extensionCount > 0: hsDegraded else: hsOk,
          message: if extensionCount > 0:
            $extensionCount & " extension(s) not ready"
          else: "")
        var status = hsOk
        for check in checks:
          if check.status == hsFailed:
            status = hsFailed
            break
          elif check.status == hsDegraded:
            status = hsDegraded
        HealthSnapshot(
          appName: appName,
          appVersion: appVersion,
          identifier: appIdentifier,
          runtimeVersion: AvelraVersion,
          protocol: 1,
          startedAt: startedAt,
          uptimeMs: (getMonoTime() - startedMono).inMilliseconds,
          platformOs: hostOs(),
          platformArch: platformArchitecture(),
          webview: platformWebview(),
          status: status,
          checks: checks,
          extensions: extensions)
    )
    try:
      # Linux hides the window until the overlay is installed; experimental
      # platforms show it immediately and have a no-op loading port.
      let window = platform_window.createAppWindow(
        options.title, options.width, options.height, options.icon)
      let loading = window.installLoading()

      let context = newHandlerContext(
        env = systemEnv(),
        urlOpen = systemUrlOpen(),
        health = health,
        loading = loading,
        extensions = extensionPort,
        quit = QuitPort(quit: proc() = window.close())
      )
      let dispatcher = newDispatcher(context)
      dispatcher.registerAppHandlers()
      dispatcher.registerOsHandlers()

      # Bindings must exist before the page runs its first script.
      window.bindNativeCall(dispatcher)
      if manager != nil:
        manager.setEventSink(proc(eventName: string; data: JsonNode) =
          window.emitEvent(eventName, data))
      window.startEventPump(proc() =
        window.pumpAsync()
        if manager != nil:
          manager.pumpEvents())
      window.navigate(server.url)

      # Blocks until the user closes the window; the window owns the bridge.
      window.showAndRun()
    finally:
      if manager != nil:
        manager.shutdown()
      server.stop()
      if iconTemp.len > 0 and fileExists(iconTemp):
        removeFile(iconTemp)
  except CatchableError as exc:
    stderr.writeLine("avelra-runtime: " & exc.msg)
    quit(1)
