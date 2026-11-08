#!/usr/bin/env bash
# Build Avelra for macOS arm64.
# Experimental and unverified: run on macOS with Xcode Command Line Tools.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
LIBEXEC_DIR="${LIBEXEC_DIR:-$BUILD_DIR/libexec/avelra}"
LIB="$BUILD_DIR/vendor/webview/macos/lib/libwebview.a"
export BUILD_DIR LIBEXEC_DIR

mkdir -p "$LIBEXEC_DIR" "$BUILD_DIR/nimcache-macos"
if [[ ! -f "$LIB" ]]; then
  "$ROOT/scripts/webview/macos.sh"
fi
if [[ ! -f "$LIB" ]]; then
  echo "libwebview.a is missing; run scripts/webview/macos.sh" >&2
  exit 1
fi

nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  --threads:on \
  --os:macosx --cpu:arm64 \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache-macos" \
  --out:"$LIBEXEC_DIR/avelra-runtime" \
  --passL:"$LIB" \
  --passL:"-framework WebKit" \
  --passL:"-framework Cocoa" \
  --passL:"-ldl" \
  --passL:"-lc++" \
  src/avelra.nim

# Keep the local prefix shaped like an SDK even though this experimental
# script currently builds only the runtime.
SHARE_DIR="$BUILD_DIR/share/avelra/templates/app"
rm -rf "$SHARE_DIR"
mkdir -p "$(dirname "$SHARE_DIR")"
cp -a "$ROOT/share/avelra/templates/app" "$SHARE_DIR"
