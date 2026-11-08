## Bind/listen error diagnostics tests.

import std/[net, strutils, unittest]

import adapters/http/static_server

suite "bind diagnostics":
  test "formats the real reason":
    check formatBindFailure("Address already in use") ==
      "cannot start static server on 127.0.0.1: Address already in use"

  test "empty reason becomes unknown":
    check formatBindFailure("") ==
      "cannot start static server on 127.0.0.1: unknown error"

  test "long reasons are truncated with NUL":
    var buffer: array[BindErrorSize, char]
    setBindError(buffer, repeat('x', 1000))
    check bindErrorText(buffer).len == BindErrorSize - 1

  test "buffer text stops at NUL":
    var buffer: array[BindErrorSize, char]
    setBindError(buffer, "permission denied")
    check bindErrorText(buffer) == "permission denied"

  test "a real bind failure carries the OS message":
    let first = newSocket()
    try:
      first.bindAddr(Port(0), "127.0.0.1")
      first.listen()
      let (_, port) = first.getLocalAddr()
      let second = newSocket()
      try:
        second.bindAddr(port, "127.0.0.1")
        check false
      except OSError as exc:
        check exc.msg.len > 0
      finally:
        second.close()
    finally:
      first.close()
