## Extension routing/lifecycle tests.

import std/[json, os, tables, unittest]

import application/dispatcher
import support
import cli/config
import domain/native_call
import extensions/manager
import ports/[env_port, loading_port]

let root = getTempDir() / ("avelra-extension-manager-" & $getCurrentProcessId())
let executable = absolutePath(testBin("extension_echo"))
removeDir(root)
createDir(root)

proc makeConfig(timeoutMs = 30000; command: seq[string] = @[executable]): ExtensionConfig =
  result = ExtensionConfig(
    id: "echo",
    protocol: 1,
    autoStart: false,
    requestTimeoutMs: timeoutMs,
    commands: initTable[string, seq[string]]()
  )
  result.commands["linux"] = command

try:
  suite "extension manager":
    test "routes ext.id.method and returns success":
      let manager = newExtensionManager(@[makeConfig()], root)
      let response = manager.dispatch("ext.echo.echo", %*{"value": 7})
      check response.success
      check response.returnValue["echo"]["value"].getInt() == 7
      manager.shutdown()

    test "unknown extension and method are method-not-found":
      let manager = newExtensionManager(@[makeConfig()], root)
      let unknown = manager.dispatch("ext.missing.echo", %*{})
      check not unknown.success
      check unknown.error.code == ErrMethodNotFound
      let malformed = manager.dispatch("ext.echo", %*{})
      check not malformed.success
      manager.shutdown()

    test "RPC errors become extension failures":
      let manager = newExtensionManager(@[makeConfig()], root)
      let response = manager.dispatch("ext.echo.fail", %*{})
      check not response.success
      check response.error.code == ErrExtensionFailed
      check response.error.message == "intentional failure"
      manager.shutdown()

    test "timeouts stop the host":
      let manager = newExtensionManager(@[makeConfig(timeoutMs = 100)], root)
      let response = manager.dispatch("ext.echo.slow", %*{})
      check not response.success
      check response.error.code == ErrExtensionFailed
      manager.shutdown()

    test "crashed host fails safely":
      let manager = newExtensionManager(
        @[makeConfig(command = @[executable, "--die-after-init"])], root)
      let response = manager.dispatch("ext.echo.echo", %*{})
      check not response.success
      check response.error.code == ErrExtensionFailed
      manager.shutdown()

    test "events are namespaced and delivered":
      var events: seq[string]
      let manager = newExtensionManager(@[makeConfig()], root,
        onEvent = proc(name: string; data: JsonNode) =
          events.add(name & ":" & $data["loaded"].getInt())
      )
      let response = manager.dispatch("ext.echo.emit", %*{})
      check response.success
      check events == @["ext.echo.progress:1"]
      manager.shutdown()

    test "dispatcher routes ext.* through the port":
      let manager = newExtensionManager(@[makeConfig()], root)
      let dispatcher = newDispatcher(newHandlerContext(
        EnvPort(), LoadingPort(), manager.extensionPort()
      ))
      let response = dispatcher.dispatch(NativeCall(
        nativeMethod: "ext.echo.echo",
        data: %*{"from": "dispatcher"}
      ))
      check response.success
      check response.returnValue["echo"]["from"].getStr() == "dispatcher"
      manager.shutdown()
finally:
  removeDir(root)
