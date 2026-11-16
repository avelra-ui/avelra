## Domain types for the native-call protocol.
##
## This module knows nothing about webview, GTK, JSON transport details beyond
## the payload envelope, or any platform API.

import std/json

const
  ## No handler is registered for the requested method.
  ErrMethodNotFound* = "NE_RT_NATNOTSUP"
  ## The request is malformed or a handler raised a CatchableError.
  ErrInvalidRequest* = "NE_RT_NATRTER"
  ## A valid operation could not be completed by the platform handler.
  ErrOperationFailed* = "NE_RT_OPFAILED"
  ## No extension/command is available for the current platform.
  ErrExtensionUnavailable* = "NE_RT_EXTUNAVAILABLE"
  ## Extension failed to start, crashed, timed out, or returned an error.
  ErrExtensionFailed* = "NE_RT_EXTFAILED"
  ## Another synchronous request is already in flight for this extension.
  ErrExtensionBusy* = "NE_RT_EXTBUSY"

type
  NativeCall* = object
    ## A single method invocation decoded from the JS bridge.
    nativeMethod*: string ## Wire key `method`; renamed to avoid the Nim keyword.
    data*: JsonNode       ## Optional argument payload; JSON null when absent.

  NativeError* = object
    ## Machine-readable error code and a human-readable message.
    code*: string
    message*: string

  NativeResult* = object
    ## Outcome of a native call, independent of the transport.
    success*: bool
    returnValue*: JsonNode ## Present only for successful calls with a value.
    error*: NativeError    ## Present only when `success` is false.

  NativeCallError* = object of CatchableError
    ## Raised when the bridge payload cannot be decoded into a NativeCall.

proc field*(node: JsonNode; key: string): JsonNode =
  ## Missing fields are represented as JSON null, so handlers do not need
  ## nil checks for every optional argument.
  if node.kind == JObject and node.hasKey(key):
    node[key]
  else:
    newJNull()

proc parseCall*(request: string): NativeCall =
  ## `request` is the JSON array produced by webview_bind from JS arguments:
  ## `[{"method": "...", "data": {...}}]`.
  let args = parseJson(request)
  if args.kind != JArray or args.len == 0:
    raise newException(NativeCallError,
      "expected a JSON array with at least one argument")

  let call = args[0]
  if call.kind != JObject:
    raise newException(NativeCallError, "native call must be an object")

  let nativeMethod = call.field("method").getStr("")
  if nativeMethod.len == 0:
    raise newException(NativeCallError, "native call is missing a method")

  result = NativeCall(nativeMethod: nativeMethod, data: call.field("data"))

proc ok*(): NativeResult =
  ## Successful result without a return value (`{"success": true}`).
  NativeResult(success: true)

proc ok*(value: JsonNode): NativeResult =
  ## Successful result carrying a JSON return value.
  NativeResult(success: true, returnValue: value)

proc fail*(code, message: string): NativeResult =
  ## Failed result with a documented error code.
  NativeResult(success: false, error: NativeError(code: code, message: message))

proc toJson*(response: NativeResult): JsonNode =
  ## Serializes the result into the wire envelope consumed by the JS client.
  if response.success:
    result = %*{"success": true}
    if response.returnValue != nil:
      result["returnValue"] = response.returnValue
  else:
    result = %*{
      "success": false,
      "error": {
        "code": response.error.code,
        "message": response.error.message
      }
    }
