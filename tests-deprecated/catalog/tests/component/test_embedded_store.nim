## EmbeddedStore and payload selection tests.

import std/[os, unittest]

import adapters/archive/[payload, zip_store]
import adapters/http/resource_store

let root = getTempDir() / ("avelra-embedded-store-" & $getCurrentProcessId())
removeDir(root)
createDir(root)

let archive = buildZip(@[
  ZipEntry(path: "index.html", data: "<h1>Embedded</h1>"),
  ZipEntry(path: "assets/app.js", data: "console.log('embedded');"),
  ZipEntry(path: "docs/index.html", data: "<h1>Docs</h1>")
])

var store = newEmbeddedStore(archive)
try:
  suite "embedded resource store":
    test "root resolves to index.html":
      let found = store.get("")
      check found.found
      check found.resource.contentType == "text/html"
      check found.resource.data == "<h1>Embedded</h1>"

    test "assets keep their MIME type":
      let found = store.get("assets/app.js")
      check found.found
      check found.resource.contentType == "text/javascript"
      check found.resource.data == "console.log('embedded');"

    test "directory paths use index.html":
      let found = store.get("docs")
      check found.found
      check found.resource.data == "<h1>Docs</h1>"

    test "missing assets are not found":
      let found = store.get("missing.js")
      check not found.found
      check found.error == notFound

    test "openResourceStore prefers the embedded payload":
      let path = root / "packed"
      writeFile(path, appendPayload("BINARY", archive))
      var opened = openResourceStore(path, root / "missing-client")
      check opened.kind == embedded
      check opened.get("index.html").found
      opened.close()
      removeFile(path)

    test "openResourceStore falls back to the directory":
      let client = root / "client"
      let binary = root / "plain"
      createDir(client)
      writeFile(client / "index.html", "<h1>Directory</h1>")
      writeFile(binary, "BINARY")
      var opened = openResourceStore(binary, client)
      check opened.kind == directory
      check opened.get("").resource.data == "<h1>Directory</h1>"
      opened.close()
      removeFile(binary)

    test "corrupted payload CRC is rejected":
      var packed = appendPayload("BINARY", archive)
      packed[packed.len - 12] = char(ord(packed[packed.len - 12]) xor 0xFF)
      let path = root / "broken"
      writeFile(path, packed)
      expect PayloadError:
        discard openResourceStore(path, root / "missing-client")
      removeFile(path)
finally:
  store.close()
  removeDir(root)
