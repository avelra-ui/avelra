#!/usr/bin/env bash
# Build one universal npm tarball from the published v0.1.0 platform archives.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(cat "$ROOT/VERSION")"
INPUT="${1:-$ROOT/build/verify-release}"
OUT="${2:-$ROOT/build/npm}"
PACKAGE="$ROOT/packages/npm"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
INPUT="$(cd "$INPUT" && pwd)"

for name in avelra-sdk-$VERSION-linux-x64.tar.gz \
            avelra-sdk-$VERSION-windows-x64.zip \
            avelra-sdk-$VERSION-macos-arm64.tar.gz; do
  [[ -f "$INPUT/$name" ]] || {
    echo "missing $INPUT/$name" >&2
    exit 1
  }
done

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -a "$PACKAGE/." "$STAGE/"
rm -rf "$STAGE/platform"
mkdir -p "$STAGE/platform"/{linux-x64,win32-x64,darwin-arm64} "$OUT"

tar -xzf "$INPUT/avelra-sdk-$VERSION-linux-x64.tar.gz" \
  -C "$STAGE/platform/linux-x64" --strip-components=1
unzip -q "$INPUT/avelra-sdk-$VERSION-windows-x64.zip" -d "$STAGE/tmp-win"
cp -a "$STAGE/tmp-win/avelra-sdk-$VERSION-windows-x64/." "$STAGE/platform/win32-x64/"
rm -rf "$STAGE/tmp-win"
tar -xzf "$INPUT/avelra-sdk-$VERSION-macos-arm64.tar.gz" \
  -C "$STAGE/platform/darwin-arm64" --strip-components=1

chmod +x "$STAGE/platform/linux-x64/bin/avelra" \
  "$STAGE/platform/darwin-arm64/bin/avelra" \
  "$STAGE/platform/linux-x64/libexec/avelra/avelra-runtime" \
  "$STAGE/platform/linux-x64/libexec/avelra/avelra-pack" \
  "$STAGE/platform/darwin-arm64/libexec/avelra/avelra-runtime" \
  "$STAGE/platform/darwin-arm64/libexec/avelra/avelra-pack"

(cd "$STAGE" && npm pack --pack-destination "$OUT" >/dev/null)
echo "$OUT/avelra-$VERSION.tgz"
