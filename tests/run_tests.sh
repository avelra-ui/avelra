#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$#" -eq 0 ]; then
  set -- --run-plan "$ROOT/tests/catalog/run-plans/host.yaml"
fi
exec python3 "$ROOT/tests/catalog/run-case.py" "$@"
