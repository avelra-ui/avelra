#!/usr/bin/env bash
# Build the user-facing Avelra CLI into the SDK prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
export AVELRA_VERSION="$VERSION"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
BIN_DIR="${BIN_DIR:-$BUILD_DIR/bin}"

mkdir -p "$BIN_DIR" "$BUILD_DIR/nimcache-cli"

nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  -d:avelraVersion="$VERSION" \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache-cli" \
  --out:"$BIN_DIR/avelra" \
  src/bin/avelra_cli.nim
