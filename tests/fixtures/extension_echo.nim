## Minimal extension used by extension-host tests.

import std/[json, os, strutils, syncio]

var protocol = 1
var badInit = false
var dieAfterInit = false
let arguments = commandLineParams()
var index = 0
while index < arguments.len:
  case arguments[index]
  of "--protocol":
    inc index
    if index < arguments.len:
      protocol = parseInt(arguments[index])
  of "--bad-init":
    badInit = true
  of "--die-after-init":
    dieAfterInit = true
  else:
    discard
  inc index

proc writeMessage(node: JsonNode) =
  stdout.writeLine($node)
  flushFile(stdout)

var line: string
while stdin.readLine(line):
  if line.len == 0:
    continue
  let message = parseJson(line)
  let methodName = message{"method"}.getStr()
  if methodName == "initialize":
    if badInit:
      stdout.writeLine("not-json")
      flushFile(stdout)
      quit(0)
    writeMessage(%*{
      "jsonrpc": "2.0",
      "id": message["id"],
      "result": {
        "name": "echo",
        "version": "1.0.0",
        "protocol": protocol,
        "methods": ["echo", "fail", "slow", "emit"]
      }
    })
    if dieAfterInit:
      quit(0)
  elif methodName == "echo":
    writeMessage(%*{
      "jsonrpc": "2.0",
      "id": message["id"],
      "result": {"echo": message{"params"}}
    })
  elif methodName == "fail":
    writeMessage(%*{
      "jsonrpc": "2.0",
      "id": message["id"],
      "error": {"code": -32042, "message": "intentional failure"}
    })
  elif methodName == "slow":
    sleep(1000)
    writeMessage(%*{
      "jsonrpc": "2.0",
      "id": message["id"],
      "result": {"slow": true}
    })
  elif methodName == "emit":
    writeMessage(%*{
      "jsonrpc": "2.0",
      "method": "event",
      "params": {"name": "progress", "data": {"loaded": 1, "total": 2}}
    })
    writeMessage(%*{
      "jsonrpc": "2.0",
      "id": message["id"],
      "result": {"emitted": true}
    })
  elif methodName == "shutdown":
    break
  elif message.hasKey("id"):
    writeMessage(%*{
      "jsonrpc": "2.0",
      "id": message["id"],
      "error": {"code": -32601, "message": "method not found"}
    })
