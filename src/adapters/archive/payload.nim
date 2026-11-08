## Payload footer for the post-build single-executable.
##
## Layout (little-endian, 48 bytes):
##   magic[16] "AVELRA_PAYLOAD\0\0"
##   version u16
##   flags u16
##   offset u64
##   length u64
##   crc32 u32
##   reserved u64

import std/[options, os, strutils]

import adapters/archive/zip_store

const
  PayloadMagic* = "AVELRA_PAYLOAD\0\0"
  PayloadVersion* = 1'u16
  PayloadFooterSize* = 48

static:
  doAssert PayloadMagic.len == 16
  doAssert PayloadFooterSize == 48

type
  PayloadError* = object of CatchableError

  PayloadFooter* = object
    version*: uint16
    offset*: uint64
    length*: uint64
    crc*: uint32

proc fail(message: string) {.noreturn.} =
  raise newException(PayloadError, message)

proc addU16(target: var string; value: uint16) =
  target.add char(int(value and 0xFF))
  target.add char(int((value shr 8) and 0xFF))

proc addU32(target: var string; value: uint32) =
  for shift in [0, 8, 16, 24]:
    target.add char(int((value shr shift) and 0xFF))

proc addU64(target: var string; value: uint64) =
  for shift in [0, 8, 16, 24, 32, 40, 48, 56]:
    target.add char(int((value shr shift) and 0xFF))

proc readU16(data: string; position: int): uint16 =
  uint16(ord(data[position])) or (uint16(ord(data[position + 1])) shl 8)

proc readU32(data: string; position: int): uint32 =
  uint32(ord(data[position])) or
    (uint32(ord(data[position + 1])) shl 8) or
    (uint32(ord(data[position + 2])) shl 16) or
    (uint32(ord(data[position + 3])) shl 24)

proc readU64(data: string; position: int): uint64 =
  var value = 0'u64
  for index in 0 .. 7:
    value = value or (uint64(ord(data[position + index])) shl (index * 8))
  value

proc buildPayloadFooter*(offset, length: uint64; crc: uint32;
                         version = PayloadVersion): string =
  ## Builds the fixed-size footer that follows the ZIP payload.
  result = PayloadMagic
  result.addU16(version)
  result.addU16(0)
  result.addU64(offset)
  result.addU64(length)
  result.addU32(crc)
  result.addU64(0)
  doAssert result.len == PayloadFooterSize

proc appendPayload*(binary, archive: string): string =
  ## Appends a ZIP archive and its footer to an existing executable.
  let footer = buildPayloadFooter(
    offset = uint64(binary.len),
    length = uint64(archive.len),
    crc = crc32(archive)
  )
  result = binary
  result.add archive
  result.add footer

proc parsePayloadFooter*(tail: string): PayloadFooter =
  ## Parses a footer that starts at `tail[0]`.
  if tail.len != PayloadFooterSize:
    fail("invalid payload footer size")
  if not tail.startsWith(PayloadMagic):
    fail("payload magic not found")
  let version = readU16(tail, 16)
  if version != PayloadVersion:
    fail("unsupported payload version")
  result = PayloadFooter(
    version: version,
    offset: readU64(tail, 20),
    length: readU64(tail, 28),
    crc: readU32(tail, 36)
  )

proc tryReadPayloadFooter*(tail: string): Option[PayloadFooter] =
  ## Returns `none` when the tail has no payload magic.
  if tail.len < PayloadFooterSize or not tail.startsWith(PayloadMagic):
    return none(PayloadFooter)
  some(parsePayloadFooter(tail))

proc readPayloadFooter*(path: string): Option[PayloadFooter] =
  ## Reads the last footer bytes of a file, if present.
  let size = getFileSize(path)
  if size < int64(PayloadFooterSize):
    return none(PayloadFooter)

  var file = open(path, fmRead)
  try:
    setFilePos(file, size - int64(PayloadFooterSize))
    var tail = newString(PayloadFooterSize)
    let read = readBuffer(file, addr tail[0], PayloadFooterSize)
    if read != PayloadFooterSize:
      fail("could not read payload footer")
    result = tryReadPayloadFooter(tail)
  finally:
    close(file)
