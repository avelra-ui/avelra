#!/usr/bin/env bash
# Build Avelra for macOS (arm64 or x64).
# Experimental and unverified: run on macOS with Xcode Command Line Tools.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
ARCH="${AVELRA_MACOS_ARCH:-arm64}"
case "$ARCH" in
  arm64) NIM_CPU=arm64; CLANG_ARCH=arm64 ;;
  x64) NIM_CPU=amd64; CLANG_ARCH=x86_64 ;;
  *) echo "unsupported macOS arch: $ARCH" >&2; exit 2 ;;
esac
BIN_DIR="${BIN_DIR:-$BUILD_DIR/bin}"
LIBEXEC_DIR="${LIBEXEC_DIR:-$BUILD_DIR/libexec/avelra}"
LIB="$BUILD_DIR/vendor/webview/macos/lib/libwebview.a"
export BUILD_DIR LIBEXEC_DIR

mkdir -p "$BIN_DIR" "$LIBEXEC_DIR" "$BUILD_DIR/nimcache-macos-$ARCH"
VERSION="$(cat "$ROOT/VERSION")"
COMMON=(c -d:release --opt:size --mm:orc -d:strip --hints:off
  "--os:macosx" "--cpu:$NIM_CPU" "--path:src" "-d:avelraVersion=$VERSION"
  "--passC:-arch" "--passC:$CLANG_ARCH" "--passL:-arch" "--passL:$CLANG_ARCH")
if [[ ! -f "$LIB" ]]; then
  "$ROOT/scripts/webview/macos.sh"
fi
if [[ ! -f "$LIB" ]]; then
  echo "libwebview.a is missing; run scripts/webview/macos.sh" >&2
  exit 1
fi

nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  --threads:on \
  --os:macosx --cpu:$NIM_CPU \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache-macos-$ARCH" \
  --out:"$LIBEXEC_DIR/avelra-runtime" \
  --passC:-arch --passC:$CLANG_ARCH --passL:-arch --passL:$CLANG_ARCH \
  --passL:"$LIB" \
  --passL:"-framework WebKit" \
  --passL:"-framework Cocoa" \
  --passL:"-ldl" \
  --passL:"-lc++" \
  src/avelra.nim

nim "${COMMON[@]}" \
  --nimcache:"$BUILD_DIR/nimcache-cli" \
  --out:"$BIN_DIR/avelra" \
  src/bin/avelra_cli.nim

nim "${COMMON[@]}" \
  --threads:on \
  --nimcache:"$BUILD_DIR/nimcache-pack" \
  --out:"$LIBEXEC_DIR/avelra-pack" \
  src/bin/avelra_pack.nim

# Keep the local prefix shaped like an SDK even though this experimental
# script currently builds only the runtime.
SHARE_DIR="$BUILD_DIR/share/avelra/templates/app"
rm -rf "$SHARE_DIR"
mkdir -p "$(dirname "$SHARE_DIR")"
cp -a "$ROOT/share/avelra/templates/app" "$SHARE_DIR"
