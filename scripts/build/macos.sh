#!/usr/bin/env bash
# Build Avelra for native macOS architecture (arm64 or x86_64).
# Experimental and unverified: run on macOS with Xcode Command Line Tools.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
BIN_DIR="${BIN_DIR:-$BUILD_DIR/bin}"
LIBEXEC_DIR="${LIBEXEC_DIR:-$BUILD_DIR/libexec/avelra}"
ARCH="${AVELRA_MACOS_ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64) CPU=arm64 ;;
  x86_64) CPU=amd64 ;;
  *) echo "unsupported macOS architecture: $ARCH" >&2; exit 2 ;;
esac
LIB="$BUILD_DIR/vendor/webview/macos/$ARCH/lib/libwebview.a"
export BUILD_DIR LIBEXEC_DIR AVELRA_MACOS_ARCH="$ARCH"

mkdir -p "$BIN_DIR" "$LIBEXEC_DIR" "$BUILD_DIR/nimcache-macos-$ARCH"
VERSION="$(cat "$ROOT/VERSION")"
COMMON=(c -d:release --opt:size --mm:orc -d:strip --hints:off
  --os:macosx --cpu:$CPU --path:src "-d:avelraVersion=$VERSION"
  --passC:-arch --passC:$ARCH --passL:-arch --passL:$ARCH)
if [[ ! -f "$LIB" ]]; then
  "$ROOT/scripts/webview/macos.sh"
fi
if [[ ! -f "$LIB" ]]; then
  echo "libwebview.a is missing; run scripts/webview/macos.sh" >&2
  exit 1
fi

nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  --threads:on \
  --os:macosx --cpu:$CPU \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache-macos-$ARCH" \
  --out:"$LIBEXEC_DIR/avelra-runtime" \
  --passC:-arch --passC:$ARCH --passL:-arch --passL:$ARCH \
  --passL:"$LIB" \
  --passL:"-framework WebKit" \
  --passL:"-framework Cocoa" \
  --passL:"-ldl" \
  --passL:"-lc++" \
  src/avelra.nim

nim "${COMMON[@]}" \
  --nimcache:"$BUILD_DIR/nimcache-cli-$ARCH" \
  --out:"$BIN_DIR/avelra" \
  src/bin/avelra_cli.nim

nim "${COMMON[@]}" \
  --threads:on \
  --nimcache:"$BUILD_DIR/nimcache-pack-$ARCH" \
  --out:"$LIBEXEC_DIR/avelra-pack" \
  src/bin/avelra_pack.nim

# Keep the local prefix shaped like an SDK even though this experimental
# script currently builds only the runtime.
SHARE_DIR="$BUILD_DIR/share/avelra/templates/app"
rm -rf "$SHARE_DIR"
mkdir -p "$(dirname "$SHARE_DIR")"
cp -a "$ROOT/share/avelra/templates/app" "$SHARE_DIR"
