#!/bin/bash
# Build the source packages of one series into binary .debs the way Launchpad does: clean ubuntu:<series>
# userland, build dependencies installed first, the build itself without network.
# Usage: ./test-build.sh <series>        -> out/<series>/bin/*.deb
#   CI_NO_PODMAN=1 ./test-build.sh <s>    run directly on this host (CI job container is ubuntu:<series>)
set -euo pipefail; shopt -s inherit_errexit
cd "$(dirname "$0")"; R=$PWD; . ./pins.env
S=${1:?usage: test-build.sh <series>}; O=$R/out/$S; B=$R/work/tb-$S
mkdir -p "$O/bin"; rm -rf "$B"; mkdir -p "$B"
SUDO=; [ "$(id -u)" = 0 ] || SUDO=sudo

# phase scripts, run inside the container (or on the host with CI_NO_PODMAN)
cat > "$B/deps.sh" <<'EOS'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends build-essential devscripts equivs quilt fakeroot >/dev/null
if ls /w/extra/*.deb >/dev/null 2>&1; then apt-get install -y -qq --no-install-recommends /w/extra/*.deb >/dev/null; fi
cd /w/src && mk-build-deps -i -r -t 'apt-get -y -qq --no-install-recommends' debian/control >/dev/null
EOS
cat > "$B/build.sh" <<'EOS'
set -euo pipefail
cd /w/src && dpkg-buildpackage -b -us -uc -j"$(nproc)" >/w/build.log 2>&1 || { tail -40 /w/build.log; exit 1; }
cp /w/*.deb /w/out/
EOS

build_one() {  # src [extra-deb...]
  local src=$1; shift; local w=$B/$src
  mkdir -p "$w/extra" "$w/out"; [ $# -gt 0 ] && cp "$@" "$w/extra/"
  dpkg-source -x "$O"/${src}_*ppa"${PPA_REV}~${S}"1.dsc "$w/src" >/dev/null
  cp "$B/deps.sh" "$B/build.sh" "$w/"
  if [ "${CI_NO_PODMAN:-}" = 1 ]; then
    $SUDO ln -sfn "$w" /w
    $SUDO bash /w/deps.sh
    bash /w/build.sh                      # (no network isolation on the host)
    $SUDO rm -f /w
  else
    local img=localhost/xrdp-ppa-deps-$S-$src
    podman rm -f "deps-$S-$src" >/dev/null 2>&1 || true
    podman run --name "deps-$S-$src" -v "$w:/w:Z" "docker.io/library/ubuntu:$S" bash /w/deps.sh
    podman commit -q "deps-$S-$src" "$img" >/dev/null; podman rm -f "deps-$S-$src" >/dev/null
    podman run --rm --network=none -v "$w:/w:Z" "$img" bash /w/build.sh
  fi
  cp "$w"/out/*.deb "$O/bin/"
}

build_one xrdp
build_one xorgxrdp "$O"/bin/xrdp_*_amd64.deb
if ls "$O"/xrdp-desktop-sessions_*ppa"${PPA_REV}~${S}"1.dsc >/dev/null 2>&1; then build_one xrdp-desktop-sessions; fi
ls -1 "$O/bin"
