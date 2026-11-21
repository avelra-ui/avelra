#!/usr/bin/env bash
# Compile component test binaries from the canonical test tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD_DIR="$ROOT/build"; BIN_DIR="$BUILD_DIR/bin"; LIBEXEC_DIR="$BUILD_DIR/libexec/avelra"
TEST_DIR="$BUILD_DIR/tests"; TEST_BIN="$TEST_DIR/bin"; NIMCACHE="$TEST_DIR/nimcache"; TEST_TMP="$TEST_DIR/tmp"
mkdir -p "$BIN_DIR" "$LIBEXEC_DIR" "$TEST_BIN" "$NIMCACHE"; rm -rf "$TEST_TMP"; mkdir -p "$TEST_TMP"
export TMPDIR="$TEST_TMP" AVELRA_CLI="$BIN_DIR/avelra" AVELRA_PACK="$LIBEXEC_DIR/avelra-pack" AVELRA_TEST_BIN="$TEST_BIN"
SHARE_DIR="$BUILD_DIR/share/avelra/templates/app"; rm -rf "$SHARE_DIR"; mkdir -p "$(dirname "$SHARE_DIR")"; cp -a "$ROOT/share/avelra/templates/app" "$SHARE_DIR"
"$ROOT/scripts/build/pack.sh" >/dev/null; "$ROOT/scripts/build/cli.sh" >/dev/null; "$ROOT/scripts/build/installer.sh" >/dev/null
compile_test() { nim c --hints:off --mm:orc --threads:on --path:src --path:tests-deprecated --path:"$ROOT/tests-deprecated/catalog/tests" --nimcache:"$NIMCACHE" --out:"$TEST_BIN/$1" "$2"; }
for f in "$ROOT"/tests-deprecated/catalog/tests/component/test_*.nim; do
  name="$(basename "$f" .nim)"
  compile_test "$name" "$f"
done
compile_test single_exe_harness "$ROOT/tests-deprecated/single_exe_harness.nim"
compile_test extension_echo "$ROOT/tests-deprecated/fixtures/extension_echo.nim"
echo "test binaries built in $TEST_BIN"
