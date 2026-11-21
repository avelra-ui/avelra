#!/usr/bin/env bash
set -euo pipefail
case "${AVELRA_CASE:-}" in
  RELEASE-001|RELEASE-002) ;;
  *) echo "unsupported release case: ${AVELRA_CASE:-}" >&2; exit 2 ;;
esac
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
./scripts/release/build.sh
