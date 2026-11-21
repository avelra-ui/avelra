#!/bin/sh
set -eu

test -x /sdk/bin/avelra
/sdk/bin/avelra init /tmp/app
cd /tmp/app
/sdk/bin/avelra build

set +e
/sdk/bin/avelra doctor >/tmp/doctor.out 2>&1
doctor_code=$?
/sdk/bin/avelra run >/tmp/run.out 2>&1
run_code=$?
set -e

cat /tmp/doctor.out
cat /tmp/run.out
test "$doctor_code" -eq 1
test "$run_code" -eq 2
grep -q 'GTK 3: MISSING' /tmp/doctor.out
grep -q 'WebKitGTK 4.1: MISSING' /tmp/doctor.out
! grep -q 'error while loading shared libraries' /tmp/run.out
