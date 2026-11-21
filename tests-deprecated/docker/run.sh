#!/usr/bin/env bash
# Build the two Docker targets and run the dependency tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK=""
DEB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sdk) SDK="$2"; shift 2 ;;
    --deb) DEB="$2"; shift 2 ;;
    *) echo "usage: $0 --sdk <sdk.tar.gz> --deb <avelra.deb>" >&2; exit 2 ;;
  esac
done
[[ -f "$SDK" && -f "$DEB" ]] || { echo "SDK and deb are required" >&2; exit 2; }

CTX="$(mktemp -d)"
trap 'rm -rf "$CTX"' EXIT
cp "$ROOT/tests/docker/Dockerfile" "$ROOT/tests/docker/bare.sh" \
   "$ROOT/tests/docker/deb.sh" "$CTX/"
cp "$SDK" "$CTX/sdk.tar.gz"
cp "$DEB" "$CTX/avelra.deb"

export DOCKER_BUILDKIT=1
export DOCKER_CONFIG="${DOCKER_CONFIG:-$ROOT/build/.docker}"
mkdir -p "$DOCKER_CONFIG"
docker build -q --target bare -t avelra-deps-bare:test "$CTX" >/dev/null
time docker run --rm --network none avelra-deps-bare:test
docker build -q --target deb -t avelra-deps-deb:test "$CTX" >/dev/null
time docker run --rm --network none avelra-deps-deb:test
