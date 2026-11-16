#!/usr/bin/env bash
# Build the immutable release tree and SDK artifacts from the local SDK prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
RELEASES_DIR="${AVELRA_RELEASES_DIR:-$BUILD_DIR/releases}"
TARGET="${AVELRA_TARGET:-linux-x64}"
VERSION="$(cat "$ROOT/VERSION")"
BIN_DIR="$BUILD_DIR/bin"
LIBEXEC_DIR="$BUILD_DIR/libexec/avelra"
SHARE_DIR="$BUILD_DIR/share/avelra"
MODE="all"

case "${1:-}" in
  "") ;;
  --tree) MODE="tree" ;;
  --tar) MODE="tar" ;;
  --deb) MODE="deb" ;;
  *) echo "usage: $0 [--tree|--tar|--deb]" >&2; exit 2 ;;
esac

if [[ "$TARGET" != "linux-x64" ]]; then
  echo "unsupported target: $TARGET (only linux-x64 is implemented)" >&2
  exit 2
fi
for file in "$BIN_DIR/avelra" "$LIBEXEC_DIR/avelra-runtime" \
            "$LIBEXEC_DIR/avelra-pack" "$LIBEXEC_DIR/avelra-installer"; do
  if [[ ! -x "$file" ]]; then
    echo "missing $file; run scripts/build/linux.sh first" >&2
    exit 1
  fi
done
if [[ ! -f "$SHARE_DIR/templates/app/client/index.html" ]]; then
  echo "missing app template; run scripts/build/linux.sh first" >&2
  exit 1
fi
for file in LICENSE "$ROOT/scripts/release/manifest.py"; do
  [[ -f "$file" ]] || { echo "missing $file" >&2; exit 1; }
done

mkdir -p "$RELEASES_DIR"
exec 9>"$RELEASES_DIR/.lock"
if ! flock -n 9; then
  echo "another release build is running" >&2
  exit 1
fi

FINAL="$RELEASES_DIR/$VERSION/$TARGET"
if [[ -e "$FINAL" ]]; then
  echo "release already exists: $FINAL" >&2
  echo "version is immutable; bump VERSION and build a new release" >&2
  exit 1
fi

STAGE="$(mktemp -d "$RELEASES_DIR/.stage.XXXXXX")"
cleanup() {
  [[ -n "${STAGE:-}" && -d "$STAGE" ]] && rm -rf "$STAGE"
}
trap cleanup EXIT

TREE="$STAGE/tree"
mkdir -p "$TREE/bin" "$TREE/libexec" "$TREE/share/doc/avelra"
cp "$BIN_DIR/avelra" "$TREE/bin/avelra"
cp -a "$LIBEXEC_DIR" "$TREE/libexec/avelra"
cp -a "$SHARE_DIR" "$TREE/share/avelra"
cp LICENSE "$TREE/share/doc/avelra/"
if [[ -f README.md ]]; then
  cp README.md "$TREE/share/doc/avelra/"
fi
chmod 0755 "$TREE/bin/avelra" \
  "$TREE/libexec/avelra/avelra-runtime" \
  "$TREE/libexec/avelra/avelra-pack" \
  "$TREE/libexec/avelra/avelra-installer" \
  "$TREE/share/doc/avelra" 2>/dev/null || true

# Validate the staged tree before it becomes visible as a release.
for file in "$TREE/bin/avelra" \
            "$TREE/libexec/avelra/avelra-runtime" \
            "$TREE/libexec/avelra/avelra-pack" \
            "$TREE/libexec/avelra/avelra-installer" \
            "$TREE/share/avelra/templates/app/client/index.html" \
            "$TREE/share/doc/avelra/LICENSE"; do
  [[ -f "$file" ]] || { echo "release tree is missing: $file" >&2; exit 1; }
done
for file in "$TREE/bin/avelra" \
            "$TREE/libexec/avelra/avelra-runtime" \
            "$TREE/libexec/avelra/avelra-pack" \
            "$TREE/libexec/avelra/avelra-installer"; do
  [[ -x "$file" ]] || { echo "release tree is not executable: $file" >&2; exit 1; }
done
CLI_VERSION="$("$TREE/bin/avelra" --version | awk '{print $2}')"
if [[ "$CLI_VERSION" != "$VERSION" ]]; then
  echo "VERSION/CLI mismatch: VERSION=$VERSION, avelra --version=$CLI_VERSION" >&2
  exit 1
fi

COMMIT="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
python3 "$ROOT/scripts/release/manifest.py" \
  --tree "$TREE" --version "$VERSION" --target "$TARGET" \
  --commit "$COMMIT" --output "$STAGE/manifest.json"

SDK_NAME="avelra-sdk-$VERSION-$TARGET"
if [[ "$MODE" != "tree" ]]; then
  mkdir -p "$STAGE/artifacts"
fi
if [[ "$MODE" == "all" || "$MODE" == "tar" ]]; then
  mkdir -p "$STAGE/tarroot/$SDK_NAME"
  cp -a "$TREE/." "$STAGE/tarroot/$SDK_NAME/"
  tar -czf "$STAGE/artifacts/$SDK_NAME.tar.gz" \
    -C "$STAGE/tarroot" "$SDK_NAME"
fi

if [[ "$MODE" == "all" || "$MODE" == "deb" ]]; then
  command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required for --deb" >&2
    exit 1
  }
  DEB_ROOT="$STAGE/debroot"
  mkdir -p "$DEB_ROOT/DEBIAN" "$DEB_ROOT/usr/bin" \
    "$DEB_ROOT/usr/libexec" "$DEB_ROOT/usr/share/doc/avelra"
  cp "$TREE/bin/avelra" "$DEB_ROOT/usr/bin/avelra"
  cp -a "$TREE/libexec/avelra" "$DEB_ROOT/usr/libexec/"
  cp -a "$TREE/share/avelra" "$DEB_ROOT/usr/share/"
  if [[ -f "$TREE/share/doc/avelra/README.md" ]]; then
    cp "$TREE/share/doc/avelra/README.md" "$DEB_ROOT/usr/share/doc/avelra/README.md"
  fi
  cp "$TREE/share/doc/avelra/LICENSE" "$DEB_ROOT/usr/share/doc/avelra/copyright"
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
  dpkg-deb --root-owner-group --build "$DEB_ROOT" \
    "$STAGE/artifacts/avelra_${VERSION}_amd64.deb"
fi

rm -rf "$STAGE/debroot" "$STAGE/tarroot"

(
  cd "$STAGE"
  sha256sum manifest.json > SHA256SUMS
  if [[ -d artifacts ]]; then
    (cd artifacts && sha256sum * >> ../SHA256SUMS)
  fi
)

mkdir -p "$(dirname "$FINAL")"
mv "$STAGE" "$FINAL"
STAGE=""
ln -s "$VERSION/$TARGET" "$RELEASES_DIR/.current.$$"
mv -Tf "$RELEASES_DIR/.current.$$" "$RELEASES_DIR/current"
trap - EXIT

echo "release: $FINAL"
echo "artifacts: $FINAL/artifacts"
