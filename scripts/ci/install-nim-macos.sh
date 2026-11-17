#!/usr/bin/env bash
# Install the official prebuilt Nim archive on macOS.
set -euo pipefail

VERSION="${1:-2.2.12}"
case "$(uname -m)" in
  x86_64) ARCH="x64" ;;
  arm64) ARCH="arm64" ;;
  *) echo "unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac

case "$VERSION/$ARCH" in
  2.2.12/x64)
    SHA256="a09fa096aeb5f6ef32f8839eced2591e145e526e42f56c79e04a18519b8b132c"
    ;;
  2.2.12/arm64)
    SHA256="130a43eff76c1c3cc78b89329a7efd892c1f65839dbc6d8e53651f3f77516fe5"
    ;;
  *)
    echo "no pinned Nim checksum for $VERSION/$ARCH" >&2
    exit 1
    ;;
esac

TMP="${RUNNER_TEMP:-/tmp}"
ARCHIVE="$TMP/nim-$VERSION-macosx_$ARCH.tar.xz"
curl -A 'Mozilla/5.0' -fsSL --retry 3 \
  "https://nim-lang.org/download/nim-${VERSION}-macosx_${ARCH}.tar.xz" \
  -o "$ARCHIVE"
actual="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [ "$actual" != "$SHA256" ]; then
  echo "Nim macOS checksum mismatch: $actual" >&2
  exit 1
fi
rm -rf "$TMP/nim-$VERSION"
tar -xJf "$ARCHIVE" -C "$TMP"
echo "$TMP/nim-$VERSION/bin" >> "${GITHUB_PATH:?GITHUB_PATH is required}"
"$TMP/nim-$VERSION/bin/nim" -v
