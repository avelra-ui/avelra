#!/bin/sh
set -eu

command -v avelra
avelra doctor
avelra init /tmp/app
cd /tmp/app
avelra build
apt-get remove -y avelra >/tmp/remove.out
hash -r
if command -v avelra >/dev/null 2>&1; then
  echo "avelra is still on PATH after removal" >&2
  exit 1
fi
test ! -e /usr/bin/avelra
echo "deb install/uninstall: OK"
