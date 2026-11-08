#!/usr/bin/env bash
# Build webview/webview as a static library against system GTK/WebKit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
SRC="$BUILD_DIR/webview-src"
BUILD="$SRC/build"
OUT="$BUILD_DIR/vendor/webview/lib"
VERSION="0.12.0"

cd "$ROOT"

# Pin the upstream tag for reproducible builds; the checkout stays generated.
if [[ ! -d "$SRC/.git" ]]; then
  rm -rf "$SRC"
  git clone --depth 1 --branch "$VERSION" \
    https://github.com/webview/webview.git "$SRC"
fi

# PIC is required because the Nim runtime is linked as a PIE.
cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DWEBVIEW_BUILD=ON \
  -DWEBVIEW_BUILD_STATIC_LIBRARY=ON \
  -DWEBVIEW_BUILD_SHARED_LIBRARY=OFF \
  -DWEBVIEW_BUILD_EXAMPLES=OFF \
  -DWEBVIEW_BUILD_TESTS=OFF \
  -DWEBVIEW_BUILD_DOCS=OFF \
  -DWEBVIEW_WEBKITGTK_API=4.1

cmake --build "$BUILD" -j"$(nproc)"

# Only the artifacts the Nim build needs are kept outside build/; the header
# is a small tracked reference file.
mkdir -p "$OUT" "$ROOT/vendor/webview/include/webview"
cp "$BUILD/core/libwebview.a" "$OUT/"
cp "$SRC/core/include/webview/webview.h" "$ROOT/vendor/webview/include/webview/"
printf 'webview/webview %s\nhttps://github.com/webview/webview/tree/%s\n' \
  "$VERSION" "$VERSION" > "$ROOT/vendor/webview/VERSION"
