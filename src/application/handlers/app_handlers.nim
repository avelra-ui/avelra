## Built-in `app.*` methods.

import std/[json, times]

import application/dispatcher
import domain/native_call
import ports/health_port

proc handlePing(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Bridge smoke test: echoes the request payload back to the page.
  result = ok(%*{
    "message": "pong",
    "echo": call.data,
    "runtime": "nim"
  })

proc healthPayload(snapshot: HealthSnapshot): JsonNode

proc handleReady(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## UI lifecycle signal: the page has painted its first content.
  if ctx.loading.hide != nil:
    ctx.loading.hide()
  result = ok()

proc healthStatusName(status: HealthStatus): string =
  case status
  of hsOk: "ok"
  of hsDegraded: "degraded"
  of hsFailed: "failed"

proc healthPayload(snapshot: HealthSnapshot): JsonNode =
  ## Serializes the public health contract; reused by the test-only probe.
  var checks = newJArray()
  for check in snapshot.checks:
    checks.add(%*{
      "id": check.id,
      "status": healthStatusName(check.status),
      "message": check.message
    })
  var extensions = newJArray()
  for extension in snapshot.extensions:
    var entry = %*{
      "id": extension.id,
      "status": extension.status,
      "protocol": extension.protocol
    }
    entry["lastErrorCode"] =
      if extension.lastErrorCode.len > 0: %extension.lastErrorCode
      else: newJNull()
    extensions.add entry
  result = %*{
    "schema": 1,
    "status": healthStatusName(snapshot.status),
    "healthy": snapshot.status == hsOk,
    "checkedAt": now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    "app": {
      "name": snapshot.appName,
      "version": snapshot.appVersion,
      "identifier": snapshot.identifier
    },
    "runtime": {
      "version": snapshot.runtimeVersion,
      "protocol": snapshot.protocol,
      "startedAt": snapshot.startedAt,
      "uptimeMs": snapshot.uptimeMs
    },
    "platform": {
      "os": snapshot.platformOs,
      "arch": snapshot.platformArch,
      "webview": snapshot.webview
    },
    "checks": checks,
    "extensions": extensions
  }

proc handleHealthCheck(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Returns a read-only snapshot of runtime and application health.
  if ctx.health.snapshot == nil:
    return fail(ErrInvalidRequest, "health provider is unavailable")
  result = ok(healthPayload(ctx.health.snapshot()))

proc handleExit(call: NativeCall; ctx: HandlerContext): NativeResult =
  ## Requests a clean window close; the platform run loop performs cleanup.
  if ctx.quit.quit == nil:
    return fail(ErrMethodNotFound, "app.exit is not available on this platform")
  ctx.quit.quit()
  result = ok()

proc registerAppHandlers*(dispatcher: Dispatcher) =
  ## Registers the built-in `app.*` namespace.
  dispatcher.register("app.ping", handlePing)
  dispatcher.register("app.ready", handleReady)
  dispatcher.register("app.healthCheck", handleHealthCheck)
  dispatcher.register("app.exit", handleExit)
