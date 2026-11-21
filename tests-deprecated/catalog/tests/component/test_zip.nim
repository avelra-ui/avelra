## ZIP store-only writer/reader tests.

import std/[options, unittest]

import adapters/archive/zip_store

suite "zip store-only":
  test "CRC32 matches the standard check value":
    check crc32("123456789") == 0xCBF43926'u32

  test "empty archive has no entries":
    let archive = buildZip(newSeq[ZipEntry]())
    check listZip(archive).len == 0
    check readZipEntry(archive, "index.html").isNone

  test "nested, binary, and UTF-8 entries round-trip":
    let entries = @[
      ZipEntry(path: "index.html", data: "<h1>Hello</h1>"),
      ZipEntry(path: "assets/app.js", data: "console.log('ok');"),
      ZipEntry(path: "data.bin", data: "\x00\x01\x02\xFF")
    ]
    let archive = buildZip(entries)
    check listZip(archive).len == 3
    check readZipEntry(archive, "index.html") == some("<h1>Hello</h1>")
    check readZipEntry(archive, "assets/app.js") ==
      some("console.log('ok');")
    check readZipEntry(archive, "data.bin") == some("\x00\x01\x02\xFF")

  test "missing entries return none":
    let archive = buildZip(@[ZipEntry(path: "index.html", data: "x")])
    check readZipEntry(archive, "missing.js").isNone

  test "duplicate paths are rejected":
    expect ZipError:
      discard buildZip(@[
        ZipEntry(path: "index.html", data: "a"),
        ZipEntry(path: "index.html", data: "b")
      ])

  test "unsafe paths are rejected":
    for path in ["../secret", "/etc/passwd", "a/../b", "a\\b", "a//b", ""]:
      expect ZipError:
        discard buildZip(@[ZipEntry(path: path, data: "x")])

  test "corrupted data fails the CRC check":
    let archive = buildZip(@[ZipEntry(path: "index.html", data: "hello")])
    let info = listZip(archive)[0]
    var broken = archive
    let dataOffset = info.localOffset + 30 + info.path.len
    broken[dataOffset] = char(ord(broken[dataOffset]) xor 0xFF)
    expect ZipError:
      discard readZipEntry(broken, "index.html")
