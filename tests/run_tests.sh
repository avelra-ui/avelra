#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/tests/catalog/run-case.py" \
  --case cli.version \
  --run-plan "$ROOT/tests/catalog/run-plans/local.yaml"
