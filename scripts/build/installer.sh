#!/usr/bin/env bash
# Build the internal Linux installer tool into the SDK prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
export AVELRA_VERSION="$VERSION"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
LIBEXEC_DIR="${LIBEXEC_DIR:-$BUILD_DIR/libexec/avelra}"

mkdir -p "$LIBEXEC_DIR" "$BUILD_DIR/nimcache-installer"

nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  -d:avelraVersion="$VERSION" \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache-installer" \
  --out:"$LIBEXEC_DIR/avelra-installer" \
  src/bin/avelra_installer.nim
