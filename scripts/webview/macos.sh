#!/usr/bin/env bash
# Build webview/webview as a static library for macOS (arm64 or x64).
# Unverified: run on macOS with Xcode Command Line Tools and CMake.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
SRC="$BUILD_DIR/webview-src"
ARCH="${AVELRA_MACOS_ARCH:-arm64}"
case "$ARCH" in
  arm64|x64) ;;
  *) echo "unsupported macOS arch: $ARCH" >&2; exit 2 ;;
esac
BUILD="$SRC/build-macos-$ARCH"
OUT="$BUILD_DIR/vendor/webview/macos/lib"
VERSION="0.12.0"

cd "$ROOT"

if [[ ! -d "$SRC/.git" ]]; then
  rm -rf "$SRC"
  git clone --depth 1 --branch "$VERSION" \
    https://github.com/webview/webview.git "$SRC"
fi

cmake -S "$SRC" -B "$BUILD" -G Xcode \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=$ARCH \
  -DWEBVIEW_BUILD=ON \
  -DWEBVIEW_BUILD_STATIC_LIBRARY=ON \
  -DWEBVIEW_ENABLE_CHECKS=OFF \
  -DWEBVIEW_BUILD_SHARED_LIBRARY=OFF \
  -DWEBVIEW_BUILD_EXAMPLES=OFF \
  -DWEBVIEW_BUILD_TESTS=OFF \
  -DWEBVIEW_BUILD_DOCS=OFF

cmake --build "$BUILD" --config Release --parallel

LIB="$(find "$BUILD" -name libwebview.a -type f | head -n 1)"
if [[ -z "$LIB" ]]; then
  echo "libwebview.a was not produced" >&2
  exit 1
fi

mkdir -p "$OUT" "$ROOT/vendor/webview/include/webview"
cp "$LIB" "$OUT/libwebview.a"
cp "$SRC/core/include/webview/webview.h" \
  "$ROOT/vendor/webview/include/webview/webview.h"

echo "Built $OUT/libwebview.a"
