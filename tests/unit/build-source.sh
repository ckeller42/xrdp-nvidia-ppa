#!/bin/bash
# build-source.sh produces per-series source packages with the right versions and an orig tarball
# that contains the git submodules (Launchpad builds offline). Usage: tests/unit/build-source.sh [series]
set -euo pipefail; cd "$(dirname "$0")/../.."; S=${1:-noble}
. ./pins.env
./build-source.sh "$S" >/dev/null
XV="${UPSTREAM_VERSION}+git${XRDP_DATE}.${XRDP_COMMIT:0:7}"; OV="${UPSTREAM_VERSION}+git${XORGXRDP_DATE}.${XORGXRDP_COMMIT:0:7}"
L=$(mktemp); tar -tJf "out/xrdp_${XV}.orig.tar.xz" > "$L"     # (grep -q on a pipe would SIGPIPE tar)
grep -q 'librfxcodec/src/rfxencode.c' "$L"; grep -q '/libpainter/src/' "$L"; rm -f "$L"
grep -q "^Version: ${XV}-0ppa${PPA_REV}~${S}1\$" out/$S/xrdp_*.dsc
grep -q "^Version: 1:${OV}-0ppa${PPA_REV}~${S}1\$" out/$S/xorgxrdp_*.dsc
grep -q "^Distribution: ${S}\$" out/$S/xrdp_*_source.changes
dpkg-source -x out/$S/xrdp_*.dsc "$(mktemp -d)/x" >/dev/null   # unpacks + applies all patches
echo BUILD-SOURCE-OK
