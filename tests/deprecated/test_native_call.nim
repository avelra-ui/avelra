## Protocol-level tests. These do not need a GUI, WebView, or GTK.
## They pin the observable wire contract: parsing rules and JSON envelopes.

import std/[json, unittest]

import domain/native_call

suite "native call protocol":
  test "parses method and data":
    let call = parseCall("""[{"method":"app.ping","data":{"value":42}}]""")
    check call.nativeMethod == "app.ping"
    check call.data["value"].getInt == 42

  test "missing data becomes JSON null":
    let call = parseCall("""[{"method":"app.ready"}]""")
    check call.nativeMethod == "app.ready"
    check call.data.kind == JNull

  test "rejects an empty argument list":
    expect NativeCallError:
      discard parseCall("[]")

  test "rejects a call without a method":
    expect NativeCallError:
      discard parseCall("""[{"data":{}}]""")

  test "serializes a successful result with a value":
    let response = toJson(ok(%*{"message": "pong"}))
    check response["success"].getBool
    check response["returnValue"]["message"].getStr == "pong"

  test "serializes a bare successful result":
    let response = toJson(ok())
    check response["success"].getBool
    check not response.hasKey("returnValue")

  test "serializes an error result":
    let response = toJson(fail("NE_X", "boom"))
    check not response["success"].getBool
    check response["error"]["code"].getStr == "NE_X"
    check response["error"]["message"].getStr == "boom"
