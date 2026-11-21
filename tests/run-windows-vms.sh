#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${AVELRA_WINDOWS_PROVIDER:?set AVELRA_WINDOWS_PROVIDER}"
: "${VM_SNAPSHOT_DIR:?set VM_SNAPSHOT_DIR}"
for distro in windows-10-22h2 windows-11-26h2; do
  echo "=== $distro"
  AVELRA_VM_SNAPSHOT="$VM_SNAPSHOT_DIR/$distro.json" \
    "$ROOT/tests/run_tests.sh" \
      --suite "$ROOT/tests/catalog/suites/windows-vm.yaml" \
      --provider "vm-$distro"
done
