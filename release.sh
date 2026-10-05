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
lv="${LVGL_VERSION}+ds-0ppa${PPA_REV}"
pkgs() { echo "lvgl ${lv}~${1}1"; echo "xrdp ${xv}~${1}1"; echo "xorgxrdp ${ov}~${1}1"; echo "xrdp-desktop-sessions ${sv}~${1}1"; }
# Resumable: packages already in the PPA (e.g. after a failed upload) are skipped; only a fully
# released tag is refused.
todo=0; done_=0
for s in $SERIES; do
    while read -r src ver; do
        if ./lp-build-status.py --exists "$src" "$ver" >/dev/null; then
            echo "release.sh: skip (already in PPA): $src $ver"; done_=$((done_+1))
        else todo=$((todo+1)); fi
    done < <(pkgs "$s")
done
if [ "$todo" = 0 ]; then echo "release.sh: $want is fully released already; bump PPA_REV" >&2; exit 3; fi
echo "release.sh: $want for $SERIES: $todo to upload, $done_ already in PPA"
[ -n "$DRY" ] && exit 0
first=${SERIES%% *}
for s in $SERIES; do ./build-source.sh "$s" ${KEY:+--sign "$KEY"} >/dev/null; done
accepted() {  # series src... : wait until Launchpad accepted these sources of that series
    local s=$1; shift; local n want=$#
    for _ in $(seq 1 60); do
        n=0; while read -r src ver; do case " $* " in *" $src "*) ./lp-build-status.py --exists "$src" "$ver" >/dev/null && n=$((n+1));; esac; done < <(pkgs "$s")
        [ "$n" = "$want" ] && return 0; sleep 60
    done
    echo "release.sh: $* for $s not accepted after 60 min" >&2; return 4
}
upload_all() {  # src... : first series (carries the orig), wait for acceptance, then the others
    local only; only=$(IFS=,; echo "$*")
    up() { ./upload.sh "$1" --only "$only" || [ $? = 3 ]; }   # 3: all already in the PPA (resumed release)
    up "$first"; accepted "$first" "$@"
    for s in $SERIES; do [ "$s" = "$first" ] || up "$s"; done
}
# Build-dependency chain inside this PPA: lvgl -> xrdp -> xorgxrdp. Upload each only once the one
# before is built AND published, otherwise Launchpad parks it in "Dependency wait" for hours.
upload_all lvgl xrdp-desktop-sessions
for s in $SERIES; do ./lp-build-status.py lvgl "${lv}~${s}1" --published-binary liblvgl-dev | tail -1; done
upload_all xrdp
for s in $SERIES; do ./lp-build-status.py xrdp "${xv}~${s}1" --published-binary xrdp | tail -1; done
upload_all xorgxrdp
rc=0
for s in $SERIES; do while read -r src ver; do ./lp-build-status.py "$src" "$ver" | tail -1 || rc=1; done < <(pkgs "$s"); done
exit $rc
