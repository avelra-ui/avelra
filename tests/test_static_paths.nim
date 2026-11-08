## Pure path/MIME tests for the static server. No sockets or threads.

import std/[os, unittest]

import adapters/http/static_paths

suite "static request paths":
  test "root maps to the empty relative path":
    let parsed = parseRequestPath("/")
    check parsed.valid
    check parsed.relative == ""

  test "assets keep their relative path":
    let parsed = parseRequestPath("/assets/app.js")
    check parsed.valid
    check parsed.relative == "assets/app.js"

  test "query strings are ignored":
    let parsed = parseRequestPath("/app.js?v=42")
    check parsed.valid
    check parsed.relative == "app.js"

  test "traversal and unsafe encodings are rejected":
    for target in [
      "/../etc/passwd",
      "/%2e%2e/etc/passwd",
      "/a/../b",
      "/a%00b",
      "/a%5Cb",
      "http://example.com/app.js"
    ]:
      check not parseRequestPath(target).valid

  test "SPA fallback only for extension-less HTML routes":
    check isSpaFallback("", "")
    check isSpaFallback("dashboard", "text/html")
    check not isSpaFallback("missing.js", "text/html")
    check not isSpaFallback("missing.js", "*/*")

  test "MIME types come from std/mimetypes":
    check contentType("app.js") == "text/javascript"
    check contentType("styles.css") == "text/css"
    check contentType("index.html") == "text/html"
    check contentType("unknown.bin") == "application/octet-stream"

  test "resolved paths stay inside the root":
    let root = getTempDir() / "avelra-static-paths"
    check resolvePath(root, "a/b.txt") == root / "a" / "b.txt"
    check containsPath(root, root / "a" / "b.txt")
    check not containsPath(root, root / ".." / "outside.txt")
