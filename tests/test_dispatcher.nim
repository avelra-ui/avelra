## Application-layer tests. Ports are replaced with fakes so handlers can be
## exercised without a real environment, GTK, or a running WebView.

import std/[json, unittest]

import application/dispatcher
import application/handlers/[app_handlers, os_handlers]
import domain/native_call
import ports/[env_port, health_port, loading_port, quit_port, url_open_port]

type
  TestState = ref object
    ## Reference type so port closures can mutate test state.
    hidden: bool
    quit: bool
    openedUrl: string
    failOpen: bool

proc makeDispatcher(state: TestState): Dispatcher =
  let env = EnvPort(
    getEnv: proc(key: string): string = "env:" & key
  )
  let loading = LoadingPort(
    hide: proc() = state.hidden = true
  )
  let urlOpen = UrlOpenPort(
    openUrl: proc(url: string): bool =
      state.openedUrl = url
      not state.failOpen
  )
  let healthSnapshot = proc(): HealthSnapshot =
    HealthSnapshot(
      appName: "demo",
      appVersion: "1.0.0",
      identifier: "com.example.demo",
      runtimeVersion: "0.2.0",
      protocol: 1,
      startedAt: "2026-01-01T00:00:00Z",
      uptimeMs: 1000,
      platformOs: "linux",
      platformArch: "amd64",
      webview: "webkitgtk-4.1",
      status: hsOk,
      checks: @[HealthCheck(id: "config", status: hsOk, message: "")],
      extensions: @[])
  let health = HealthPort(snapshot: healthSnapshot)
  let quit = QuitPort(quit: proc() = state.quit = true)
  result = newDispatcher(newHandlerContext(env, loading, urlOpen = urlOpen,
    health = health, quit = quit))
  result.registerAppHandlers()
  result.registerOsHandlers()

suite "dispatcher":
  test "app.ping returns pong and echoes data":
    let dispatcher = makeDispatcher(TestState())
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "app.ping", data: %*{"value": 42})
    )

    check response.success
    check response.returnValue["message"].getStr == "pong"
    check response.returnValue["echo"]["value"].getInt == 42
    check response.returnValue["runtime"].getStr == "nim"

  test "os.getEnv uses the env port":
    let dispatcher = makeDispatcher(TestState())
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "os.getEnv", data: %*{"key": "HOME"})
    )

    check response.success
    check response.returnValue.getStr == "env:HOME"

  test "os.openUrl forwards an http URL to the URL port":
    let state = TestState()
    let dispatcher = makeDispatcher(state)
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "os.openUrl",
        data: %*{"url": "https://avelra.dev/docs/"})
    )

    check response.success
    check state.openedUrl == "https://avelra.dev/docs/"

  test "app.healthCheck serializes runtime health":
    let dispatcher = makeDispatcher(TestState())
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "app.healthCheck", data: newJNull())
    )

    check response.success
    check response.returnValue["status"].getStr == "ok"
    check response.returnValue["healthy"].getBool
    check response.returnValue["app"]["name"].getStr == "demo"
    check response.returnValue["checks"][0]["id"].getStr == "config"

  test "os.openUrl reports a failed browser launch":
    let state = TestState(failOpen: true)
    let dispatcher = makeDispatcher(state)
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "os.openUrl",
        data: %*{"url": "https://avelra.dev/docs/"})
    )

    check not response.success
    check response.error.code == ErrOperationFailed
    check state.openedUrl == "https://avelra.dev/docs/"

  test "os.openUrl rejects non-http schemes":
    let dispatcher = makeDispatcher(TestState())
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "os.openUrl",
        data: %*{"url": "file:///etc/passwd"})
    )

    check not response.success
    check response.error.code == ErrInvalidRequest

  test "unknown methods return the documented error code":
    let dispatcher = makeDispatcher(TestState())
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "app.unknown", data: newJNull())
    )

    check not response.success
    check response.error.code == ErrMethodNotFound

  test "app.ready dismisses the loading state":
    let state = TestState()
    let dispatcher = makeDispatcher(state)
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "app.ready", data: newJNull())
    )

    check response.success
    check state.hidden

  test "app.exit closes through the quit port":
    let state = TestState()
    let dispatcher = makeDispatcher(state)
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "app.exit", data: newJNull())
    )

    check response.success
    check state.quit
