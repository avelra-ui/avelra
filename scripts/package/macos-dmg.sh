#!/usr/bin/env bash
# Package a staged macOS SDK release as an unsigned DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RELEASE_DIR="${1:-}"
if [[ -z "$RELEASE_DIR" ]]; then
  echo "usage: $0 <release-dir>" >&2
  exit 2
fi
VERSION="$(cat "$ROOT/VERSION")"
ARTIFACT_LABEL="${AVELRA_ARTIFACT_LABEL:-$VERSION}"
TARGET="${AVELRA_TARGET:-macos-x64}"
TREE="$RELEASE_DIR/tree"
ARTIFACTS="$RELEASE_DIR/artifacts"
OUT="$ARTIFACTS/avelra-$ARTIFACT_LABEL-$TARGET.dmg"

[[ -f "$TREE/bin/avelra" ]] || { echo "release tree is missing bin/avelra" >&2; exit 1; }
mkdir -p "$ARTIFACTS"
rm -f "$OUT"
hdiutil create -volname "Avelra" -srcfolder "$TREE" -ov -format UDZO "$OUT"
hash="$(shasum -a 256 "$OUT" | awk '{print $1}')"
printf '%s  %s\n' "$hash" "$(basename "$OUT")" >> "$RELEASE_DIR/SHA256SUMS"
echo "installer: $OUT"
