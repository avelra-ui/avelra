#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="${1:-$ROOT/tests/catalog/run-plans/local.yaml}"
exec python3 "$ROOT/tests/catalog/run-case.py" --run-plan "$PLAN"
