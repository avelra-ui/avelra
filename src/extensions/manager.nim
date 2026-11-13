## Routes `ext.<id>.<method>` calls to sidecar extensions.

import std/[json, tables, strutils]

import cli/config
import domain/native_call
import extensions/host
import ports/[extension_port, health_port]

type
  ExtensionEventHandler* = proc(eventName: string; data: JsonNode) {.closure.}

  ExtensionManager* = ref object
    appDir: string
    configs: Table[string, ExtensionConfig]
    hosts: Table[string, ExtensionHost]
    busy: Table[string, bool]
    lastErrors: Table[string, string]
    onEvent: ExtensionEventHandler

proc newExtensionManager*(extensions: seq[ExtensionConfig]; appDir: string;
                          onEvent: ExtensionEventHandler = nil): ExtensionManager =
  result = ExtensionManager(
    appDir: appDir,
    configs: initTable[string, ExtensionConfig](),
    hosts: initTable[string, ExtensionHost](),
    busy: initTable[string, bool](),
    lastErrors: initTable[string, string](),
    onEvent: onEvent
  )
  for config in extensions:
    result.configs[config.id] = config

proc setEventSink*(manager: ExtensionManager; sink: ExtensionEventHandler) =
  manager.onEvent = sink

proc extensionStateName(state: ExtensionState): string =
  case state
  of esReady: "running"
  of esStarting: "starting"
  of esCrashed: "failed"
  of esStopped, esStopping: "stopped"

proc health*(manager: ExtensionManager): seq[HealthExtension] =
  ## Reads current extension state without starting any host.
  for id in manager.configs.keys:
    var entry = HealthExtension(id: id, status: "stopped", protocol: 0)
    if manager.hosts.hasKey(id):
      let host = manager.hosts[id]
      entry.status = extensionStateName(host.state)
      entry.protocol = host.handshake.protocol
    if manager.lastErrors.hasKey(id):
      entry.lastErrorCode = manager.lastErrors[id]
    result.add entry

proc splitMethod(methodName: string): tuple[id, name: string] =
  if not methodName.startsWith("ext."):
    return
  let rest = methodName[4 .. ^1]
  let separator = rest.find('.')
  if separator <= 0 or separator == rest.len - 1:
    return
  (rest[0 ..< separator], rest[separator + 1 .. ^1])

proc ensureHost(manager: ExtensionManager; id: string): ExtensionHost =
  if manager.hosts.hasKey(id):
    let existing = manager.hosts[id]
    if existing.state == esReady:
      return existing
    manager.hosts.del(id)
  let config = manager.configs[id]
  let eventSink = manager.onEvent
  let extensionId = id
  proc onExtensionEvent(eventName: string; data: JsonNode) =
    if eventSink != nil:
      eventSink("ext." & extensionId & "." & eventName, data)

  result = startExtension(config, manager.appDir, onExtensionEvent)
  manager.hosts[id] = result

proc dispatch*(manager: ExtensionManager; methodName: string;
               data: JsonNode): NativeResult =
  ## Routes one native call. Never lets host exceptions escape.
  let (id, extensionMethod) = splitMethod(methodName)
  if id.len == 0:
    return fail(ErrMethodNotFound, "unknown extension method: " & methodName)
  if not manager.configs.hasKey(id):
    return fail(ErrMethodNotFound, "unknown extension: " & id)
  if manager.busy.getOrDefault(id, false):
    return fail(ErrExtensionBusy, "extension is busy: " & id)

  var host: ExtensionHost
  try:
    host = manager.ensureHost(id)
  except ExtensionStartError as exc:
    manager.lastErrors[id] = ErrExtensionUnavailable
    return fail(ErrExtensionUnavailable, exc.msg)
  except ExtensionProtocolError as exc:
    manager.lastErrors[id] = ErrExtensionFailed
    return fail(ErrExtensionFailed, exc.msg)
  except ExtensionHostError as exc:
    manager.lastErrors[id] = ErrExtensionFailed
    return fail(ErrExtensionFailed, exc.msg)

  manager.busy[id] = true
  try:
    let response = host.request(extensionMethod, data,
      timeoutMs = manager.configs[id].requestTimeoutMs)
    manager.lastErrors.del(id)
    return ok(response)
  except ExtensionRpcError as exc:
    manager.lastErrors[id] = ErrExtensionFailed
    return fail(ErrExtensionFailed, exc.msg)
  except ExtensionTimeoutError as exc:
    manager.hosts.del(id)
    manager.lastErrors[id] = ErrExtensionFailed
    stopExtension(host)
    return fail(ErrExtensionFailed, exc.msg)
  except ExtensionHostError as exc:
    manager.hosts.del(id)
    manager.lastErrors[id] = ErrExtensionFailed
    stopExtension(host)
    return fail(ErrExtensionFailed, exc.msg)
  finally:
    manager.busy[id] = false

proc pumpEvents*(manager: ExtensionManager) =
  for host in manager.hosts.values:
    try:
      host.pumpEvents()
    except CatchableError:
      discard

proc shutdown*(manager: ExtensionManager) =
  for host in manager.hosts.values:
    stopExtension(host)
  manager.hosts.clear()

proc extensionPort*(manager: ExtensionManager): ExtensionPort =
  ExtensionPort(
    dispatch: proc(methodName: string; payload: JsonNode): NativeResult =
      manager.dispatch(methodName, payload)
  )
