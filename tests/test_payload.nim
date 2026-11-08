## Payload footer and append tests.

import std/[options, os, strutils, unittest]

import adapters/archive/[payload, zip_store]

suite "payload footer":
  test "fixed-size footer round-trips":
    let footer = buildPayloadFooter(42'u64, 1234'u64, 0xDEADBEEF'u32)
    check footer.len == PayloadFooterSize
    check footer.startsWith(PayloadMagic)
    let parsed = parsePayloadFooter(footer)
    check parsed.version == PayloadVersion
    check parsed.offset == 42'u64
    check parsed.length == 1234'u64
    check parsed.crc == 0xDEADBEEF'u32

  test "appendPayload places the archive before the footer":
    let packed = appendPayload("BINARY", "ARCHIVE")
    check packed.startsWith("BINARYARCHIVE")
    let parsed = parsePayloadFooter(packed[^PayloadFooterSize .. ^1])
    check parsed.offset == 6'u64
    check parsed.length == 7'u64
    check parsed.crc == crc32("ARCHIVE")

  test "missing magic is rejected":
    let tail = repeat('\0', PayloadFooterSize)
    check tryReadPayloadFooter(tail).isNone
    expect PayloadError:
      discard parsePayloadFooter(tail)

  test "readPayloadFooter reads the last 48 bytes":
    let path = getTempDir() / ("avelra-payload-" & $getCurrentProcessId())
    defer: removeFile(path)
    writeFile(path, appendPayload("BINARY", "ARCHIVE"))
    let parsed = readPayloadFooter(path).get
    check parsed.offset == 6'u64
    check parsed.length == 7'u64
