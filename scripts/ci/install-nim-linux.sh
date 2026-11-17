#!/usr/bin/env bash
# Install the official prebuilt Nim archive on Linux x64.
set -euo pipefail

VERSION="${1:-2.2.12}"
SHA256="7df1611449a6842af69322aa2c1206942982650a5f6bc0d37bc8ec109932f638"
URL="https://nim-lang.org/download/nim-${VERSION}-linux_x64.tar.xz"
TMP="${RUNNER_TEMP:-/tmp}"
ARCHIVE="$TMP/nim-$VERSION-linux_x64.tar.xz"

curl -A 'Mozilla/5.0' -fsSL --retry 3 "$URL" -o "$ARCHIVE"
echo "$SHA256  $ARCHIVE" | sha256sum -c -
rm -rf "$TMP/nim-$VERSION"
tar -xJf "$ARCHIVE" -C "$TMP"
echo "$TMP/nim-$VERSION/bin" >> "${GITHUB_PATH:?GITHUB_PATH is required}"
"$TMP/nim-$VERSION/bin/nim" -v
