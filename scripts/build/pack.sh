#!/usr/bin/env bash
# Build the post-build single-executable packer into the SDK prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
export AVELRA_VERSION="$VERSION"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
LIBEXEC_DIR="${LIBEXEC_DIR:-$BUILD_DIR/libexec/avelra}"

mkdir -p "$LIBEXEC_DIR" "$BUILD_DIR/nimcache-pack"

nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  -d:avelraVersion="$VERSION" \
  --threads:on \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache-pack" \
  --out:"$LIBEXEC_DIR/avelra-pack" \
  src/bin/avelra_pack.nim
