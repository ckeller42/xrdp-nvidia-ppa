#!/bin/bash
# piuparts: install, purge and upgrade-from-Ubuntu's-xrdp of the built debs in a fresh debootstrap chroot,
# then check nothing is left behind. Needs root and piuparts (in Ubuntu only from resolute on; CI runs it
# in a privileged ubuntu:resolute container for every target series).
# Usage: tests/piuparts.sh <series>   (after test-build.sh <series>)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")/.."; S=${1:?usage: piuparts.sh <series>}; B=out/$S/bin
# ponytail: xrdp-gnome-session left out, it pulls in the whole GNOME desktop (~1 GB); add if its scripts grow
piuparts -d "$S" --mirror "http://archive.ubuntu.com/ubuntu main universe" --warn-on-debsums-errors \
  --ignore=/lib.usr-is-merged/ `# marker of the usr-merge transition in a bare debootstrap, not ours` \
  "$B"/xrdp_*.deb "$B"/xorgxrdp_*.deb "$B"/xrdp-nvidia-session_*.deb
