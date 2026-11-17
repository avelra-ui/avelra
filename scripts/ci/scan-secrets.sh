#!/usr/bin/env bash
# Run a pinned gitleaks binary without a third-party action.
set -euo pipefail

VERSION="8.30.1"
SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
TMP="${RUNNER_TEMP:-/tmp}"
ARCHIVE="$TMP/gitleaks_${VERSION}_linux_x64.tar.gz"
BIN="$TMP/gitleaks-${VERSION}"

curl -fsSL --retry 3 \
  "https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_linux_x64.tar.gz" \
  -o "$ARCHIVE"
echo "$SHA256  $ARCHIVE" | sha256sum -c -
rm -rf "$BIN"
mkdir -p "$BIN"
tar -xzf "$ARCHIVE" -C "$BIN" gitleaks
"$BIN/gitleaks" detect \
  --source . \
  --redact \
  --verbose \
  --exit-code 1
