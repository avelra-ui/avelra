#!/usr/bin/env bash
# Run headless unit tests; no DISPLAY, WebKit, or GTK is required.
# --portable runs the cross-platform subset against binaries already built by
# the platform job; it does not invoke Linux build/package scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORTABLE=0
if [[ "${1:-}" == "--portable" ]]; then
  PORTABLE=1
  shift
fi
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) EXE=".exe" ;;
  *) EXE="" ;;
esac

BUILD_DIR="$ROOT/build"
BIN_DIR="$BUILD_DIR/bin"
LIBEXEC_DIR="$BUILD_DIR/libexec/avelra"
TEST_DIR="$BUILD_DIR/tests"
TEST_BIN="$TEST_DIR/bin"
NIMCACHE="$TEST_DIR/nimcache"
TEST_TMP="$TEST_DIR/tmp"

mkdir -p "$BIN_DIR" "$LIBEXEC_DIR" "$TEST_BIN" "$NIMCACHE" "$TEST_TMP"
rm -rf "$TEST_TMP"
mkdir -p "$TEST_TMP"

export TMPDIR="$TEST_TMP"
export AVELRA_CLI="${AVELRA_CLI:-$BIN_DIR/avelra$EXE}"
export AVELRA_PACK="${AVELRA_PACK:-$LIBEXEC_DIR/avelra-pack$EXE}"
export AVELRA_TEST_BIN="${AVELRA_TEST_BIN:-$TEST_BIN}"

if (( ! PORTABLE )); then
  # The CLI resolves init templates through its SDK prefix; tests run against
  # build/bin without requiring the full GUI build.
  SHARE_DIR="$BUILD_DIR/share/avelra/templates/app"
  rm -rf "$SHARE_DIR"
  mkdir -p "$(dirname "$SHARE_DIR")"
  cp -a "$ROOT/share/avelra/templates/app" "$SHARE_DIR"

  "$ROOT/scripts/build/pack.sh" >/dev/null
  "$ROOT/scripts/build/cli.sh" >/dev/null
  "$ROOT/scripts/build/installer.sh" >/dev/null
fi

compile_test() {
  local name="$1"
  local source="$2"
  nim c --hints:off --mm:orc --threads:on --path:src --path:tests \
    --nimcache:"$NIMCACHE" \
    --out:"$TEST_BIN/$name$EXE" \
    "$source"
}

run_test() {
  local name="$1"
  compile_test "$name" "tests/$name.nim"
  "$TEST_BIN/$name$EXE"
}

compile_test single_exe_harness tests/single_exe_harness.nim
compile_test extension_echo tests/fixtures/extension_echo.nim

if (( PORTABLE )); then
  run_test test_native_call
  run_test test_dispatcher
  run_test test_url_policy
  run_test test_static_paths
  run_test test_resource_store
  run_test test_zip
  run_test test_payload
  run_test test_embedded_store
  run_test test_bind_error
  run_test test_platform_checks
  run_test test_cli_config
  run_test test_extension_config
else
  compile_test single_exe_harness tests/single_exe_harness.nim
  compile_test extension_echo tests/fixtures/extension_echo.nim

  run_test test_native_call
  run_test test_dispatcher
  run_test test_url_policy
  run_test test_static_paths
  run_test test_resource_store
  run_test test_zip
  run_test test_payload
  run_test test_embedded_store
  run_test test_pack_cli
  run_test test_single_exe
  run_test test_bind_error
  run_test test_runtime_deps
  run_test test_platform_checks
  run_test test_cli_config
  run_test test_cli_layout
  run_test test_cli_help
  run_test test_cli_init
  run_test test_cli_build
  run_test test_cli_run
  run_test test_installer
  run_test test_sdk_package
  run_test test_extension_config
  run_test test_extension_host
  run_test test_extension_manager
  run_test test_static_server

  "$ROOT/tests/test_release.sh"
fi
