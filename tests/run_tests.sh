#!/usr/bin/env bash
# Compatibility shim while tests/deprecated is replaced by tests/catalog.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tests/deprecated/run_tests.sh" "$@"
