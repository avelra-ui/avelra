#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${AVELRA_VM_PROVIDER:?set AVELRA_VM_PROVIDER to the VM executor}"
: "${VM_SNAPSHOT_DIR:?set VM_SNAPSHOT_DIR to the snapshot directory}"
for distro in ubuntu-22.04 ubuntu-24.04 ubuntu-26.04 debian-12 debian-13; do
  echo "=== $distro"
  AVELRA_VM_SNAPSHOT="$VM_SNAPSHOT_DIR/$distro.json" \
    "$ROOT/tests/run_tests.sh" \
      --suite "$ROOT/tests/catalog/suites/linux-vm.yaml" \
      --provider "vm-$distro"
done
