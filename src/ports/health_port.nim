## Port for application/runtime health snapshots.
##
## The composition root collects platform and process facts; the application
## layer only serializes the immutable snapshot into the native-call envelope.

type
  HealthStatus* = enum
    hsOk
    hsDegraded
    hsFailed

  HealthCheck* = object
    id*: string
    status*: HealthStatus
    message*: string

  HealthExtension* = object
    id*: string
    status*: string
    protocol*: int
    lastErrorCode*: string

  HealthSnapshot* = object
    appName*: string
    appVersion*: string
    identifier*: string
    runtimeVersion*: string
    protocol*: int
    startedAt*: string
    uptimeMs*: int64
    platformOs*: string
    platformArch*: string
    webview*: string
    status*: HealthStatus
    checks*: seq[HealthCheck]
    extensions*: seq[HealthExtension]

  HealthPort* = object
    ## Returns a current snapshot without changing application state.
    snapshot*: proc(): HealthSnapshot {.closure.}
