#!/usr/bin/env bash
# Build the Linux SDK prefix: bin/avelra + libexec/avelra/* + share/avelra/*.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
export AVELRA_VERSION="$VERSION"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
BIN_DIR="${BIN_DIR:-$BUILD_DIR/bin}"
LIBEXEC_DIR="${LIBEXEC_DIR:-$BUILD_DIR/libexec/avelra}"
SHARE_DIR="${SHARE_DIR:-$BUILD_DIR/share/avelra/templates/app}"
WEBVIEW_LIB="${WEBVIEW_LIB:-$BUILD_DIR/vendor/webview/lib/libwebview.a}"

export BUILD_DIR BIN_DIR LIBEXEC_DIR

mkdir -p "$BIN_DIR" "$LIBEXEC_DIR" "$BUILD_DIR/nimcache"

if [[ ! -f "$WEBVIEW_LIB" ]]; then
  "$ROOT/scripts/webview/linux.sh"
fi

# Link order matters: libwebview.a must precede the libraries it depends on.
LINK_FLAGS=()
add_flag() {
  LINK_FLAGS+=(--passL:"$1")
}

add_flag "$WEBVIEW_LIB"
add_flag "-lstdc++"
add_flag "-lm"
add_flag "-ldl"
add_flag "-lpthread"

while IFS= read -r flag; do
  [[ -n "$flag" ]] && add_flag "$flag"
done < <(pkg-config --libs gtk+-3.0 webkit2gtk-4.1 | xargs -n1)

# --path:src allows imports such as adapters/... and application/... from src.
nim c -d:release --opt:size --mm:orc -d:strip --hints:off \
  -d:avelraVersion="$VERSION" \
  --threads:on \
  --path:src \
  --nimcache:"$BUILD_DIR/nimcache" \
  --out:"$LIBEXEC_DIR/avelra-runtime" \
  "${LINK_FLAGS[@]}" \
  src/avelra.nim

# Build the user-facing CLI and internal tools used by the SDK.
"$ROOT/scripts/build/pack.sh"
"$ROOT/scripts/build/cli.sh"
"$ROOT/scripts/build/installer.sh"

# The dev prefix must be a complete SDK layout; layout.nim knows nothing about
# the repository, only about bin/ + libexec/avelra/ + share/avelra/.
rm -rf "$SHARE_DIR"
mkdir -p "$(dirname "$SHARE_DIR")"
cp -a "$ROOT/share/avelra/templates/app" "$SHARE_DIR"
