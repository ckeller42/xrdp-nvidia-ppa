#!/bin/bash
# Build Ubuntu source packages for one series from the pins in pins.env.
# Usage: ./build-source.sh <series> [--sign KEYID]
#   out/<src>_<ver>.orig.tar.xz        shared by all series, reproducible (Launchpad needs it identical)
#   out/<series>/<src>_*.dsc|.debian.tar.xz|_source.changes (+ orig link for dput)
set -euo pipefail; shopt -s inherit_errexit   # errors inside $(...) must abort too
cd "$(dirname "$0")"; R=$PWD; . ./pins.env
S=${1:?usage: build-source.sh <series> [--sign KEYID]}; shift
SIGN=()
if [ "${1:-}" = --sign ]; then SIGN=(--sign-key="$2"); else SIGN=(-us -uc); fi
first=${SERIES%% *}; [ "$S" = "$first" ] && SRCOPT=-sa || SRCOPT=-sd
export DEBEMAIL="christoph.keller@gmx.net" DEBFULLNAME="Dr. Christoph G. Keller"
W=$R/work; O=$R/out; mkdir -p "$W/src" "$O/$S"

orig() {  # src commit date -> builds out/<src>_<ver>.orig.tar.xz once, prints ver
  local src=$1 commit=$2 date=$3 ver d t
  ver="${UPSTREAM_VERSION}+git${date}.${commit:0:7}"; d=$W/src/$src
  if [ ! -f "$O/${src}_${ver}.orig.tar.xz" ]; then
    [ -d "$d/.git" ] || git clone -q https://github.com/neutrinolabs/$src.git "$d"
    git -C "$d" fetch -q origin "$commit"; git -C "$d" checkout -q -f "$commit"
    git -C "$d" submodule -q update --init --recursive
    t=$(mktemp -d); mkdir "$t/$src-$ver"
    git -C "$d" archive HEAD | tar -x -C "$t/$src-$ver"
    git -C "$d" submodule --quiet foreach --recursive \
      "git archive HEAD | tar -x -C \"$t/$src-$ver/\$displaypath\""
    # reproducible tarball: same bytes on every machine for the same pin
    tar --sort=name --mtime="@$(git -C "$d" log -1 --format=%ct)" --owner=0 --group=0 --numeric-owner \
        -C "$t" -cf - "$src-$ver" | xz -9 -T1 > "$O/${src}_${ver}.orig.tar.xz"
    rm -rf "$t"
  fi
  echo "$ver"
}

srcpkg() {  # src fullversion [orig]
  local src=$1 full=$2 orig=${3:-} b=$W/build-$S
  rm -rf "$b/$src"; mkdir -p "$b/$src"
  if [ -n "$orig" ]; then
    tar -xJf "$O/$orig" -C "$b/$src"; ln -sf "$O/$orig" "$b/$src/$orig"
    local dir; dir=$(ls -d "$b/$src"/*/); cp -a "$R/packaging/$src/debian" "$dir"
  else
    local dir=$b/$src/$src-native; cp -a "$R/packaging/$src" "$dir"
  fi
  (cd "$b/$src"/*/ && dch -b -v "$full" -D "$S" --force-distribution "PPA build for $S." \
     && dpkg-buildpackage -S -d -nc $SRCOPT "${SIGN[@]}" >/dev/null)
  mv "$b/$src"/*.dsc "$b/$src"/*.debian.tar.xz "$b/$src"/*_source.changes "$b/$src"/*_source.buildinfo "$O/$S/" 2>/dev/null || true
  mv "$b/$src"/*.tar.xz "$O/$S/" 2>/dev/null || true      # native tarball
  [ -n "$orig" ] && ln -sf "../$orig" "$O/$S/$orig"
  return 0
}

v=$(orig xrdp "$XRDP_COMMIT" "$XRDP_DATE");             srcpkg xrdp "$v-0ppa${PPA_REV}~${S}1" "xrdp_$v.orig.tar.xz"
v=$(orig xorgxrdp "$XORGXRDP_COMMIT" "$XORGXRDP_DATE"); srcpkg xorgxrdp "1:$v-0ppa${PPA_REV}~${S}1" "xorgxrdp_$v.orig.tar.xz"
if [ -d "$R/packaging/xrdp-desktop-sessions" ]; then srcpkg xrdp-desktop-sessions "1.0~ppa${PPA_REV}~${S}1"; fi
ls -1 "$O/$S"
