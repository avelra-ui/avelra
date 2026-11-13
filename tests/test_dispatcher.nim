## Application-layer tests. Ports are replaced with fakes so handlers can be
## exercised without a real environment, GTK, or a running WebView.

import std/[json, unittest]

import application/dispatcher
import application/handlers/[app_handlers, os_handlers]
import domain/native_call
import ports/[env_port, loading_port, quit_port, url_open_port]

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
  let quit = QuitPort(quit: proc() = state.quit = true)
  result = newDispatcher(newHandlerContext(env, loading, urlOpen = urlOpen,
    quit = quit))
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

  test "os.openUrl reports a failed browser launch":
    let state = TestState(failOpen: true)
    let dispatcher = makeDispatcher(state)
    let response = dispatcher.dispatch(
      NativeCall(nativeMethod: "os.openUrl",
        data: %*{"url": "https://avelra.dev/docs/"})
    )

    check not response.success
    check response.error.code == ErrInvalidRequest
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
