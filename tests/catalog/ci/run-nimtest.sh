#!/usr/bin/env bash
set -euo pipefail
# CI adapter for catalog cases with runner=ci.nimtest.
# Test name is supplied by the case adapter; never build inside a case.
name="${AVELRA_NIMTEST:-}"
[ -n "$name" ] || { echo "AVELRA_NIMTEST is required" >&2; exit 2; }
bin="${AVELRA_TEST_BIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/avelra/build/tests/bin}"
"$bin/$name"
