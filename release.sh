#!/bin/bash
# Release the pinned versions to the PPA: signed source packages for every series, upload the first
# series (it carries the orig tarballs), wait until Launchpad accepted it, upload the rest, wait for builds.
# Usage: ./release.sh [--sign KEY] [--tag vX] [--dry-run]
#   --tag: must equal v${UPSTREAM_VERSION}-0ppa${PPA_REV} (CI passes the pushed tag)
#   --dry-run: version checks only (nothing built or uploaded)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")"; . ./pins.env
KEY=; TAG=; DRY=
while [ $# -gt 0 ]; do case $1 in
    --sign) KEY=$2; shift 2;; --tag) TAG=$2; shift 2;; --dry-run) DRY=1; shift;;
    *) echo "unknown option $1" >&2; exit 64;; esac; done
want="v${UPSTREAM_VERSION}-0ppa${PPA_REV}"
if [ -n "$TAG" ] && [ "$TAG" != "$want" ]; then echo "release.sh: tag $TAG != $want (pins.env)" >&2; exit 65; fi
xv="${UPSTREAM_VERSION}+git${XRDP_DATE}.${XRDP_COMMIT:0:7}-0ppa${PPA_REV}"
ov="1:${UPSTREAM_VERSION}+git${XORGXRDP_DATE}.${XORGXRDP_COMMIT:0:7}-0ppa${PPA_REV}"
sv="1.0~ppa${PPA_REV}"
pkgs() { echo "xrdp ${xv}~${1}1"; echo "xorgxrdp ${ov}~${1}1"; echo "xrdp-desktop-sessions ${sv}~${1}1"; }
for s in $SERIES; do
    while read -r src ver; do
        if ./lp-build-status.py --exists "$src" "$ver" >/dev/null; then
            echo "release.sh: $src $ver already in $PPA; bump PPA_REV" >&2; exit 3; fi
    done < <(pkgs "$s")
done
echo "release.sh: $want for $SERIES: versions free"
[ -n "$DRY" ] && exit 0
first=${SERIES%% *}
for s in $SERIES; do ./build-source.sh "$s" ${KEY:+--sign "$KEY"} >/dev/null; done
./upload.sh "$first"
for _ in $(seq 1 60); do                       # orig tarballs must be accepted before -sd uploads
    n=0; while read -r src ver; do ./lp-build-status.py --exists "$src" "$ver" >/dev/null && n=$((n+1)); done < <(pkgs "$first")
    [ "$n" = 3 ] && break; sleep 60
done
[ "$n" = 3 ] || { echo "release.sh: $first not accepted after 60 min" >&2; exit 4; }
for s in $SERIES; do [ "$s" = "$first" ] || ./upload.sh "$s"; done
rc=0
for s in $SERIES; do while read -r src ver; do ./lp-build-status.py "$src" "$ver" | tail -1 || rc=1; done < <(pkgs "$s"); done
exit $rc
