#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/tests-deprecated/catalog/build-tests.sh"
if [ "${AVELRA_BUILD_ONLY:-0}" = "1" ]; then exit 0; fi
exec python3 "$ROOT/tests-deprecated/catalog/run-ci.py" --all-inventory
