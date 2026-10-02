#!/bin/bash
# Upload all source packages of one series to the PPA, refusing versions Launchpad already has.
# Usage: ./upload.sh <series> [--check-only] [--only src1,src2]   (exit 3: a version is already in the PPA)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")"; . ./pins.env
S=${1:?usage: upload.sh <series> [--check-only] [--only src1,src2]}; shift; CHECK=; ONLY=
while [ $# -gt 0 ]; do case $1 in --check-only) CHECK=1; shift;; --only) ONLY=$2; shift 2;; *) exit 64;; esac; done
changes=$(ls out/"$S"/*_source.changes)
if [ -n "$ONLY" ]; then
    sel=; for c in $changes; do src=$(sed -n 's/^Source: //p' "$c"); case ",$ONLY," in *",$src,"*) sel="$sel $c";; esac; done
    changes=$sel
fi
for c in $changes; do
    src=$(sed -n 's/^Source: //p' "$c"); ver=$(sed -n 's/^Version: //p' "$c")
    if ./lp-build-status.py --exists "$src" "$ver"; then
        echo "upload.sh: $src $ver is already in $PPA; bump PPA_REV in pins.env" >&2; exit 3
    fi
done
[ -n "$CHECK" ] && { echo "upload.sh: $S ready to upload"; exit 0; }
for c in $changes; do dput "$PPA" "$c"; done
