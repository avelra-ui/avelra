#!/usr/bin/env bash
# Build the Linux SDK packages for Avelra from the local SDK prefix.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT="${AVELRA_SDK_SOURCE:-$SCRIPT_ROOT}"
BUILD_DIR="${BUILD_DIR:-${AVELRA_BUILD_DIR:-$ROOT/build}}"
BIN_DIR="$BUILD_DIR/bin"
LIBEXEC_DIR="$BUILD_DIR/libexec/avelra"
SHARE_DIR="$BUILD_DIR/share/avelra/templates/app"
PACKAGE_DIR="$BUILD_DIR/packages"
cd "$ROOT"

MODE="${1:-all}"
case "$MODE" in
  all|--all) BUILD_TAR=1; BUILD_DEB=1 ;;
  --tar) BUILD_TAR=1; BUILD_DEB=0 ;;
  --deb) BUILD_TAR=0; BUILD_DEB=1 ;;
  *) echo "usage: $0 [--tar|--deb]" >&2; exit 2 ;;
esac

if [[ ! -x "$BIN_DIR/avelra" ]]; then
  echo "missing $BIN_DIR/avelra; run scripts/build/linux.sh first" >&2
  exit 1
fi
for file in avelra-runtime avelra-pack avelra-installer; do
  if [[ ! -x "$LIBEXEC_DIR/$file" ]]; then
    echo "missing $LIBEXEC_DIR/$file; run scripts/build/linux.sh first" >&2
    exit 1
  fi
done
if [[ ! -d "$SHARE_DIR" ]]; then
  echo "missing app template; run scripts/build/linux.sh first" >&2
  exit 1
fi

VERSION="${AVELRA_VERSION:-$("$BIN_DIR/avelra" --version | awk '{print $2}')}"
if [[ -z "$VERSION" ]]; then
  echo "cannot determine version" >&2
  exit 1
fi

mkdir -p "$PACKAGE_DIR"
STAGE="$(mktemp -d "$PACKAGE_DIR/.stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

SDK_NAME="avelra-sdk-$VERSION-linux-x64"
SDK_ROOT="$STAGE/$SDK_NAME"
mkdir -p "$SDK_ROOT/bin" "$SDK_ROOT/libexec" \
  "$SDK_ROOT/share" "$SDK_ROOT/share/doc/avelra"
cp "$BIN_DIR/avelra" "$SDK_ROOT/bin/avelra"
cp -a "$BUILD_DIR/libexec/avelra" "$SDK_ROOT/libexec/"
cp -a "$BUILD_DIR/share/avelra" "$SDK_ROOT/share/"
if [[ -f README.md ]]; then
  cp README.md "$SDK_ROOT/share/doc/avelra/README.md"
fi
chmod 0755 "$SDK_ROOT/bin/avelra" "$SDK_ROOT/libexec/avelra/"*

if [[ "$BUILD_TAR" == 1 ]]; then
  tar -czf "$PACKAGE_DIR/$SDK_NAME.tar.gz" -C "$STAGE" "$SDK_NAME"
  echo "created $PACKAGE_DIR/$SDK_NAME.tar.gz"
fi

if [[ "$BUILD_DEB" == 1 ]]; then
  command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required for --deb" >&2
    exit 1
  }
  DEB_ROOT="$STAGE/debroot"
  mkdir -p "$DEB_ROOT/DEBIAN" "$DEB_ROOT/usr/bin" \
    "$DEB_ROOT/usr/libexec" "$DEB_ROOT/usr/share/doc/avelra"
  cp "$BIN_DIR/avelra" "$DEB_ROOT/usr/bin/avelra"
  cp -a "$BUILD_DIR/libexec/avelra" "$DEB_ROOT/usr/libexec/"
  cp -a "$BUILD_DIR/share/avelra" "$DEB_ROOT/usr/share/"
  if [[ -f README.md ]]; then
    cp README.md "$DEB_ROOT/usr/share/doc/avelra/README.md"
  fi
  chmod 0755 "$DEB_ROOT/usr/bin/avelra" "$DEB_ROOT/usr/libexec/avelra/"*
  cat > "$DEB_ROOT/DEBIAN/control" <<CONTROL
Package: avelra
Version: $VERSION
Section: devel
Priority: optional
Architecture: amd64
Depends: libgtk-3-0t64 | libgtk-3-0, libwebkit2gtk-4.1-0
Maintainer: Avelra <contact@avelra.dev>
Description: Avelra desktop runtime and SDK
CONTROL
  dpkg-deb --build "$DEB_ROOT" "$PACKAGE_DIR/avelra_${VERSION}_amd64.deb"
  echo "created $PACKAGE_DIR/avelra_${VERSION}_amd64.deb"
fi

(
  cd "$PACKAGE_DIR"
  sha256sum avelra-sdk-*.tar.gz avelra_*_amd64.deb 2>/dev/null \
    > SHA256SUMS || true
)
echo "artifacts: $PACKAGE_DIR"
