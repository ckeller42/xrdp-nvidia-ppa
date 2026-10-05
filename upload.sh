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
# skip versions Launchpad already has (resumed release); exit 3 only if nothing is left to upload
todo=
for c in $changes; do
    src=$(sed -n 's/^Source: //p' "$c"); ver=$(sed -n 's/^Version: //p' "$c")
    if ./lp-build-status.py --exists "$src" "$ver" >/dev/null; then echo "upload.sh: skip $src $ver (already in $PPA)"
    else todo="$todo $c"; fi
done
[ -n "$todo" ] || { echo "upload.sh: everything for $S is already in $PPA; bump PPA_REV in pins.env" >&2; exit 3; }
[ -n "$CHECK" ] && { echo "upload.sh: $S ready to upload:$todo"; exit 0; }
for c in $todo; do
    # Launchpad's FTP sometimes answers 550 "internal server error": retry, forcing a re-upload
    for try in 1 2 3; do
        opts=(); [ "$try" -gt 1 ] && opts=(-f)
        if dput "${opts[@]}" "$PPA" "$c"; then break; fi
        [ "$try" = 3 ] && { echo "upload.sh: dput failed 3 times for $c" >&2; exit 1; }
        echo "upload.sh: dput failed (try $try), retrying in 60 s" >&2; sleep 60
    done
done
