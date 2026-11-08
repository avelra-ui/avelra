## DirectoryStore tests. No sockets, GUI, or WebView.

import std/[os, strutils, unittest]

import adapters/http/resource_store

let root = getTempDir() / ("avelra-resource-store-" & $getCurrentProcessId())
let outside = getTempDir() / ("avelra-resource-outside-" & $getCurrentProcessId())
removeDir(root)
createDir(root)
createDir(root / "assets")
writeFile(root / "index.html", "<h1>Hello store</h1>")
writeFile(root / "assets" / "app.js", "console.log('store');")
writeFile(outside, "outside")

var store = newDirectoryStore(root)
try:
  suite "directory resource store":
    test "root resolves to index.html":
      let found = store.get("")
      check found.found
      check found.resource.contentType == "text/html"
      check found.resource.data.contains("Hello store")

    test "assets keep their MIME type":
      let found = store.get("assets/app.js")
      check found.found
      check found.resource.contentType == "text/javascript"
      check found.resource.data.contains("store")

    test "missing files are not found":
      let found = store.get("missing.js")
      check not found.found
      check found.error == notFound

    test "traversal and absolute paths are forbidden":
      for path in ["../secret", "/etc/passwd", "a/../b"]:
        let found = store.get(path)
        check not found.found
        check found.error == forbidden

    when defined(posix):
      test "symlinks outside the root are forbidden":
        createSymlink(outside, root / "outside.txt")
        let found = store.get("outside.txt")
        check not found.found
        check found.error == forbidden
        removeFile(root / "outside.txt")
finally:
  store.close()
  removeDir(root)
  removeFile(outside)
