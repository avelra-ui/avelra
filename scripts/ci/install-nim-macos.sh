#!/usr/bin/env bash
# Install the official prebuilt Nim archive on macOS.
set -euo pipefail

VERSION="${1:-2.2.12}"
case "$(uname -m)" in
  x86_64) ARCH="x64" ;;
  arm64) ARCH="arm64" ;;
  *) echo "unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac

TMP="${RUNNER_TEMP:-/tmp}"
ARCHIVE="$TMP/nim-$VERSION-macosx_$ARCH.tar.xz"
curl -fsSL --retry 3 \
  "https://nim-lang.org/download/nim-${VERSION}-macosx_${ARCH}.tar.xz" \
  -o "$ARCHIVE"
rm -rf "$TMP/nim-$VERSION"
tar -xJf "$ARCHIVE" -C "$TMP"
echo "$TMP/nim-$VERSION/bin" >> "${GITHUB_PATH:?GITHUB_PATH is required}"
"$TMP/nim-$VERSION/bin/nim" -v
