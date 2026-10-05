#!/bin/bash
# piuparts in fresh debootstrap chroots, checking nothing is left behind after purge:
#  1. install + purge of the built debs together
#  2. upgrade from Ubuntu's own xrdp + xorgxrdp to ours, then purge. piuparts only runs the upgrade when
#     every tested package is in the archive, so liblvgl9 comes from a local repo of the built debs.
# Needs root, piuparts and dpkg-dev (piuparts is in Ubuntu only from resolute on; CI runs it in a
# privileged ubuntu:resolute container for every target series).
# Usage: tests/piuparts.sh <series>   (after test-build.sh <series>)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")/.."; S=${1:?usage: piuparts.sh <series>}; B=$PWD/out/$S/bin
common=(-d "$S" --mirror "http://archive.ubuntu.com/ubuntu main universe" --warn-on-debsums-errors
        --ignore=/lib.usr-is-merged/)   # marker of the usr-merge transition in a bare debootstrap, not ours
# ponytail: xrdp-gnome-session left out, it pulls in the whole GNOME desktop (~1 GB); add if its scripts grow
piuparts "${common[@]}" "$B"/liblvgl9_*.deb "$B"/xrdp_*.deb "$B"/xorgxrdp_*.deb "$B"/xrdp-nvidia-session_*.deb
# local repo with ONLY what Ubuntu lacks (liblvgl9): the "old" install must come from the archive
R=$PWD/work/piuparts-repo-$S; rm -rf "$R"; mkdir -p "$R"; cp "$B"/liblvgl9_*.deb "$R/"
(cd "$R" && dpkg-scanpackages . /dev/null > Packages 2>/dev/null)
L=$PWD/work/piuparts-upgrade-$S.log
piuparts "${common[@]}" --bindmount="$R" --extra-repo="deb [trusted=yes] file://$R ./" \
  "$B"/xrdp_*.deb "$B"/xorgxrdp_*.deb > "$L" 2>&1 || { tail -30 "$L"; exit 1; }
# piuparts first installs+purges our debs on their own; the archive install comes after this marker
v=$(sed -n '/apt-cache knows about the following packages/,$p' "$L" | grep -oE "Unpacking xrdp \([^)]*\)")
case $(head -1 <<<"$v") in *ppa*|"") echo "piuparts did not upgrade from the archive's xrdp: $v" >&2; exit 1;; esac
echo "piuparts upgrade test passed:" $v
