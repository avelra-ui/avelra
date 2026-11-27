#!/usr/bin/env bash
# Exercise the transactional release tree and its artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/avelra-release-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

VERSION="$(cat "$ROOT/VERSION")"
OUT="$TMP/releases"
AVELRA_RELEASES_DIR="$OUT" AVELRA_ARTIFACT_LABEL="$VERSION" SOURCE_DATE_EPOCH=1700000000 \
  "$ROOT/scripts/release/build.sh"

REL="$OUT/$VERSION/linux-x64"
test -f "$REL/manifest.json"
test -f "$REL/SHA256SUMS"
test -f "$REL/artifacts/avelra-$VERSION-linux-x64.tar.gz"
test -f "$REL/artifacts/avelra_${VERSION}_amd64.deb"
test -L "$OUT/current"
test ! -e "$REL/debroot"
test ! -e "$REL/tarroot"

python3 - "$REL" "$VERSION" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

rel = Path(sys.argv[1])
manifest = json.loads((rel / "manifest.json").read_text())
assert manifest["version"] == sys.argv[2]
paths = {entry["path"] for entry in manifest["files"]}
for required in ["bin/avelra", "libexec/avelra/avelra-runtime",
                 "share/avelra/templates/app/client/index.html",
                 "share/doc/avelra/LICENSE"]:
    assert required in paths, required
for entry in manifest["files"]:
    path = rel / "tree" / entry["path"]
    assert path.is_file(), path
    assert path.stat().st_size == entry["size"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]
PY

mkdir -p "$TMP/flat"
cp "$REL/manifest.json" "$REL/SHA256SUMS" "$REL/artifacts/"* "$TMP/flat/"
(cd "$TMP/flat" && sha256sum -c SHA256SUMS >/dev/null)

mkdir -p "$TMP/tar" "$TMP/deb"
tar -xzf "$REL/artifacts/avelra-$VERSION-linux-x64.tar.gz" -C "$TMP/tar"
"$TMP/tar/avelra-$VERSION-linux-x64/bin/avelra" --version | grep -q "avelra $VERSION"
dpkg-deb -x "$REL/artifacts/avelra_${VERSION}_amd64.deb" "$TMP/deb"
"$TMP/deb/usr/bin/avelra" --version | grep -q "avelra $VERSION"

TREE_OUT="$TMP/tree-releases"
AVELRA_RELEASES_DIR="$TREE_OUT" AVELRA_ARTIFACT_LABEL="$VERSION" "$ROOT/scripts/release/build.sh" --tree >/dev/null
TREE_REL="$TREE_OUT/$VERSION/linux-x64"
test -f "$TREE_REL/manifest.json"
test -f "$TREE_REL/SHA256SUMS"
test ! -d "$TREE_REL/artifacts"

if AVELRA_RELEASES_DIR="$OUT" "$ROOT/scripts/release/build.sh" >/dev/null 2>&1; then
  echo "second build of the same version unexpectedly succeeded" >&2
  exit 1
fi

echo "release tree test passed"
