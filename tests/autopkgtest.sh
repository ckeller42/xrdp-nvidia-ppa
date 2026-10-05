#!/bin/bash
# Run every source package's DEP-8 tests (debian/tests) against the freshly built debs, on this machine.
# Needs root; meant for the CI job container (ubuntu:<series>), which already is the isolation.
# Usage: tests/autopkgtest.sh <series>   (after test-build.sh <series>)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")/.."; . ./pins.env; S=${1:?usage: autopkgtest.sh <series>}; O=out/$S
rm -rf "work/autopkgtest-$S"   # autopkgtest refuses a non-empty output dir
for dsc in "$O"/*ppa"${PPA_REV}~${S}"1.dsc; do
  echo "== autopkgtest $(basename "$dsc")"
  autopkgtest --ignore-restrictions=isolation-container -o "work/autopkgtest-$S/$(basename "$dsc" .dsc)" \
    "$dsc" "$O"/bin/*.deb -- null
done
