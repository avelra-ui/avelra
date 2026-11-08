## Minimal standard ZIP support with the store method (no compression).
##
## The writer is used by the post-build packer; the reader is used by the
## embedded resource store. Only files are stored: directory entries, ZIP64,
## encryption, and data descriptors are intentionally unsupported.

import std/[options, sets, strutils]

const
  LocalHeaderSignature = 0x04034B50'u32
  CentralHeaderSignature = 0x02014B50'u32
  EndOfCentralDirectorySignature = 0x06054B50'u32
  Utf8Flag = 0x0800'u16
  DosDate = 0x0021'u16   # 1980-01-01
  DosTime = 0'u16

type
  ZipError* = object of CatchableError

  ZipEntry* = object
    path*: string
    data*: string

  ZipEntryInfo* = object
    path*: string
    crc*: uint32
    compressedSize*: int
    uncompressedSize*: int
    localOffset*: int

proc makeCrcTable(): array[256, uint32] =
  for i in 0 .. 255:
    var value = uint32(i)
    for _ in 0 .. 7:
      if (value and 1) != 0:
        value = 0xEDB88320'u32 xor (value shr 1)
      else:
        value = value shr 1
    result[i] = value

let CrcTable = makeCrcTable()

proc crc32*(data: string): uint32 {.gcsafe.} =
  ## Standard CRC32 (IEEE 802.3).
  var value = 0xFFFFFFFF'u32
  for ch in data:
    value = CrcTable[int((value xor uint32(ord(ch))) and 0xFF)] xor (value shr 8)
  value xor 0xFFFFFFFF'u32

proc fail(message: string) {.noreturn.} =
  raise newException(ZipError, message)

proc addU16(target: var string; value: uint16) =
  target.add char(int(value and 0xFF))
  target.add char(int((value shr 8) and 0xFF))

proc addU32(target: var string; value: uint32) =
  target.add char(int(value and 0xFF))
  target.add char(int((value shr 8) and 0xFF))
  target.add char(int((value shr 16) and 0xFF))
  target.add char(int((value shr 24) and 0xFF))

proc requireBytes(data: string; position, count: int; what: string) =
  if position < 0 or count < 0 or position > data.len - count:
    fail("truncated ZIP: " & what)

proc readU16(data: string; position: int): uint16 =
  requireBytes(data, position, 2, "uint16")
  uint16(ord(data[position])) or (uint16(ord(data[position + 1])) shl 8)

proc readU32(data: string; position: int): uint32 =
  requireBytes(data, position, 4, "uint32")
  uint32(ord(data[position])) or
    (uint32(ord(data[position + 1])) shl 8) or
    (uint32(ord(data[position + 2])) shl 16) or
    (uint32(ord(data[position + 3])) shl 24)

proc validateEntryPath*(path: string) {.gcsafe.} =
  ## Rejects empty, absolute, traversal, and Windows-hostile names.
  if path.len == 0:
    fail("empty ZIP entry path")
  if path[0] == '/' or path.contains('\\') or path.contains('\0') or
      path.contains('\r') or path.contains('\n'):
    fail("unsafe ZIP entry path: " & path)
  for part in path.split('/'):
    if part.len == 0 or part == "." or part == ".." or part.contains(':'):
      fail("unsafe ZIP entry path: " & path)

proc buildZip*(entries: openArray[ZipEntry]): string {.gcsafe.} =
  ## Builds a stored ZIP archive. Duplicate or unsafe paths are rejected.
  if entries.len > 0xFFFF:
    fail("too many ZIP entries")

  var names = initHashSet[string]()
  var central = ""

  for entry in entries:
    validateEntryPath(entry.path)
    if entry.path in names:
      fail("duplicate ZIP entry: " & entry.path)
    names.incl entry.path

    if entry.path.len > 0xFFFF:
      fail("ZIP entry path is too long: " & entry.path)
    if entry.data.len > int(high(uint32)):
      fail("ZIP entry is too large: " & entry.path)
    if result.len > int(high(uint32)):
      fail("ZIP archive is too large")

    let offset = result.len
    let digest = crc32(entry.data)

    result.addU32(LocalHeaderSignature)
    result.addU16(20)          # version needed
    result.addU16(Utf8Flag)
    result.addU16(0)           # stored
    result.addU16(DosTime)
    result.addU16(DosDate)
    result.addU32(digest)
    result.addU32(uint32(entry.data.len))
    result.addU32(uint32(entry.data.len))
    result.addU16(uint16(entry.path.len))
    result.addU16(0)           # extra length
    result.add(entry.path)
    result.add(entry.data)

    central.addU32(CentralHeaderSignature)
    central.addU16(20)         # version made by
    central.addU16(20)         # version needed
    central.addU16(Utf8Flag)
    central.addU16(0)          # stored
    central.addU16(DosTime)
    central.addU16(DosDate)
    central.addU32(digest)
    central.addU32(uint32(entry.data.len))
    central.addU32(uint32(entry.data.len))
    central.addU16(uint16(entry.path.len))
    central.addU16(0)          # extra length
    central.addU16(0)          # comment length
    central.addU16(0)          # disk number
    central.addU16(0)          # internal attributes
    central.addU32(0)          # external attributes
    central.addU32(uint32(offset))
    central.add(entry.path)

  let centralOffset = result.len
  if centralOffset > int(high(uint32)) or central.len > int(high(uint32)):
    fail("ZIP archive is too large")
  result.add(central)

  result.addU32(EndOfCentralDirectorySignature)
  result.addU16(0)             # disk number
  result.addU16(0)             # central directory disk
  result.addU16(uint16(entries.len))
  result.addU16(uint16(entries.len))
  result.addU32(uint32(central.len))
  result.addU32(uint32(centralOffset))
  result.addU16(0)             # comment length

proc listZip*(archive: string): seq[ZipEntryInfo] {.gcsafe.} =
  ## Parses the central directory and returns file entries.
  if archive.len < 22:
    fail("not a ZIP archive")

  var eocd = -1
  let minimum = max(0, archive.len - 22 - 65535)
  var eocdPos = archive.len - 22
  while eocdPos >= minimum:
    if readU32(archive, eocdPos) == EndOfCentralDirectorySignature:
      eocd = eocdPos
      break
    dec eocdPos
  if eocd < 0:
    fail("end of central directory not found")

  let disk = readU16(archive, eocd + 4)
  let centralDisk = readU16(archive, eocd + 6)
  let entriesOnDisk = readU16(archive, eocd + 8)
  let entriesTotal = readU16(archive, eocd + 10)
  let commentLength = int(readU16(archive, eocd + 20))

  if disk != 0 or centralDisk != 0 or entriesOnDisk != entriesTotal:
    fail("multi-disk ZIP archives are not supported")
  requireBytes(archive, eocd + 22, commentLength, "EOCD comment")
  if eocd + 22 + commentLength != archive.len:
    fail("trailing data after end of central directory")

  let centralSize = int(readU32(archive, eocd + 12))
  let centralOffset = int(readU32(archive, eocd + 16))
  if centralOffset < 0 or centralSize < 0 or
      centralOffset + centralSize > eocd:
    fail("invalid central directory bounds")

  var names = initHashSet[string]()
  var position = centralOffset

  for _ in 0 ..< int(entriesTotal):
    requireBytes(archive, position, 46, "central directory header")
    if readU32(archive, position) != CentralHeaderSignature:
      fail("invalid central directory entry")
    let flags = readU16(archive, position + 8)
    let compressionMethod = readU16(archive, position + 10)
    if (flags and 0x0001'u16) != 0 or (flags and 0x0008'u16) != 0:
      fail("encrypted or data-descriptor ZIP entries are not supported")
    if compressionMethod != 0:
      fail("compressed ZIP entries are not supported")

    let digest = readU32(archive, position + 16)
    let compressedSize = int(readU32(archive, position + 20))
    let uncompressedSize = int(readU32(archive, position + 24))
    if compressedSize != uncompressedSize:
      fail("stored ZIP entry has different sizes")
    let nameLength = int(readU16(archive, position + 28))
    let extraLength = int(readU16(archive, position + 30))
    let entryCommentLength = int(readU16(archive, position + 32))
    let localOffset = int(readU32(archive, position + 42))

    requireBytes(archive, position + 46,
                 nameLength + extraLength + entryCommentLength,
                 "central directory entry")
    let path = archive[position + 46 ..< position + 46 + nameLength]
    validateEntryPath(path)
    if path in names:
      fail("duplicate ZIP entry: " & path)
    names.incl path

    if localOffset < 0 or localOffset + 30 > archive.len:
      fail("invalid local header offset for " & path)

    result.add ZipEntryInfo(
      path: path,
      crc: digest,
      compressedSize: compressedSize,
      uncompressedSize: uncompressedSize,
      localOffset: localOffset
    )
    position += 46 + nameLength + extraLength + entryCommentLength

  if position != centralOffset + centralSize:
    fail("central directory size mismatch")

proc readZipEntry*(archive, path: string): Option[string] {.gcsafe.} =
  ## Returns a stored entry, verifying its CRC. Missing entries return `none`.
  for info in listZip(archive):
    if info.path != path:
      continue

    let local = info.localOffset
    requireBytes(archive, local, 30, "local header")
    if readU32(archive, local) != LocalHeaderSignature:
      fail("invalid local header for " & path)
    let flags = readU16(archive, local + 6)
    let compressionMethod = readU16(archive, local + 8)
    if (flags and 0x0001'u16) != 0 or compressionMethod != 0:
      fail("unsupported local entry for " & path)

    let nameLength = int(readU16(archive, local + 26))
    let extraLength = int(readU16(archive, local + 28))
    requireBytes(archive, local + 30, nameLength + extraLength,
                 "local entry name")
    let localName = archive[local + 30 ..< local + 30 + nameLength]
    if localName != path:
      fail("local/central name mismatch for " & path)

    let dataStart = local + 30 + nameLength + extraLength
    requireBytes(archive, dataStart, info.compressedSize, "entry data")
    let payload = archive[dataStart ..< dataStart + info.compressedSize]
    if crc32(payload) != info.crc:
      fail("CRC mismatch for " & path)
    return some(payload)

  none(string)
