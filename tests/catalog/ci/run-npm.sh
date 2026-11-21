#!/usr/bin/env bash
set -euo pipefail
[ "${AVELRA_CASE:-}" = NPM-001 ] || { echo "unsupported npm case" >&2; exit 2; }
echo "RESULT ci NPM-001 SKIP: npm case is owned by the npm workflow"
exit 0
