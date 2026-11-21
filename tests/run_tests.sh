#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$#" -eq 0 ]; then
  set -- --suite "$ROOT/tests/catalog/suites/host.yaml" --provider host-linux-x64
fi
if [ "$1" = "--suite" ]; then
  suite="$2"
  shift 2
  exec python3 "$ROOT/tests/catalog/run-suite.py" --suite "$suite" "$@"
fi
exec python3 "$ROOT/tests/catalog/run-case.py" "$@"
