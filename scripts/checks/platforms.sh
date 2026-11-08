#!/usr/bin/env bash
# Cross-check Nim code for Windows and macOS without their SDKs.
# This validates Nim syntax/types only; it is not a build or runtime test.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

NIMCACHE="$ROOT/build/check/nimcache"
mkdir -p "$NIMCACHE"

check_target() {
  local os="$1"
  local cpu="$2"
  local target="$3"
  nim check --threads:on --os:"$os" --cpu:"$cpu" --path:src --hints:off \
    --nimcache:"$NIMCACHE" "$target"
}

for target in \
  src/avelra.nim \
  src/adapters/archive/zip_store.nim \
  src/adapters/archive/payload.nim \
  src/adapters/archive/packaging.nim \
  src/bin/avelra_pack.nim \
  src/bin/avelra_cli.nim \
  src/bin/avelra_installer.nim \
  src/extensions/host.nim \
  src/extensions/manager.nim
do
  check_target windows amd64 "$target"
done

for target in \
  src/avelra.nim \
  src/adapters/archive/zip_store.nim \
  src/adapters/archive/payload.nim \
  src/adapters/archive/packaging.nim \
  src/bin/avelra_pack.nim
do
  check_target macosx arm64 "$target"
done

echo "Cross-platform Nim checks passed (windows/amd64, macosx/arm64)."
