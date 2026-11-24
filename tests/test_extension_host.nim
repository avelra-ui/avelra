## Sidecar transport and handshake tests.

import std/[json, os, tables, unittest]

import cli/config
import support
import extensions/host

let root = getTempDir() / ("avelra-extension-host-" & $getCurrentProcessId())
let fixtureExt = when defined(windows): ".exe" else: ""
let executable = absolutePath(testBin("extension_echo" & fixtureExt))
removeDir(root)
createDir(root)

proc makeConfig(id = "echo"; protocol = 1; command: seq[string] = @[executable]): ExtensionConfig =
  result = ExtensionConfig(
    id: id,
    protocol: protocol,
    autoStart: false,
    requestTimeoutMs: 30000,
    commands: initTable[string, seq[string]]()
  )
  result.commands[hostOs()] = command

try:
  suite "extension host":
    test "handshake and echo request":
      let host = startExtension(makeConfig(), root)
      check host.state == esReady
      check host.handshake.name == "echo"
      check host.handshake.protocol == 1
      check "echo" in host.handshake.methods
      let result = host.request("echo", %*{"value": 42})
      check result["echo"]["value"].getInt() == 42
      stopExtension(host)
      check host.state == esStopped

    test "RPC errors are surfaced":
      let host = startExtension(makeConfig(), root)
      try:
        discard host.request("fail")
        check false
      except ExtensionRpcError as exc:
        check exc.code == -32042
        check exc.msg == "intentional failure"
      finally:
        stopExtension(host)

    test "protocol mismatch is rejected":
      let config = makeConfig(protocol = 1, command = @[executable, "--protocol", "2"])
      expect ExtensionProtocolError:
        discard startExtension(config, root)

    test "malformed initialize is rejected":
      let config = makeConfig(command = @[executable, "--bad-init"])
      expect ExtensionProtocolError:
        discard startExtension(config, root)

    test "missing executable is rejected":
      let config = makeConfig(command = @[root / "missing-extension"])
      expect ExtensionStartError:
        discard startExtension(config, root)
finally:
  removeDir(root)
