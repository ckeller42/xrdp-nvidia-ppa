#!/bin/bash
# Run every source package's DEP-8 tests (debian/tests) against the freshly built debs, on this machine.
# Needs root; meant for the CI job container (ubuntu:<series>), which already is the isolation.
# Usage: tests/autopkgtest.sh <series>   (after test-build.sh <series>)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")/.."; . ./pins.env; S=${1:?usage: autopkgtest.sh <series>}; O=out/$S
# the null runner installs the debs and starts daemons on THIS system: containers only
[ -e /.dockerenv ] || [ -e /run/.containerenv ] || [ -n "${CI:-}" ] || { echo "run in a container (CI)" >&2; exit 2; }
shopt -s nullglob; dscs=("$O"/*ppa"${PPA_REV}~${S}"1.dsc)
[ ${#dscs[@]} -gt 0 ] || { echo "no $O/*ppa${PPA_REV}~${S}1.dsc; run build-source.sh first" >&2; exit 2; }
rm -rf "work/autopkgtest-$S"   # autopkgtest refuses a non-empty output dir
for dsc in "${dscs[@]}"; do
  echo "== autopkgtest $(basename "$dsc")"
  autopkgtest --ignore-restrictions=isolation-container -o "work/autopkgtest-$S/$(basename "$dsc" .dsc)" \
    "$dsc" "$O"/bin/*.deb -- null
done
