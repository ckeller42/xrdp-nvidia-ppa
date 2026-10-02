#!/bin/bash
# test-build.sh builds all source packages of a series offline in a clean container.
# Usage: tests/unit/test-build.sh [series]
set -euo pipefail; cd "$(dirname "$0")/../.."; S=${1:-noble}
./build-source.sh "$S" >/dev/null 2>&1
rm -rf "out/$S/bin"; ./test-build.sh "$S"
for p in xrdp xorgxrdp; do ls out/$S/bin/${p}_*.deb >/dev/null; done
X=$(ls out/$S/bin/xrdp_*.deb); test "$(dpkg-deb -c "$X" | grep -c 'xrdp/xrdp-accel-assist$')" = 1
D=$(mktemp -d); dpkg-deb -x "$X" "$D"; strings "$D/usr/sbin/xrdp" > "$D/strings"   # (no grep -q on pipes: SIGPIPE)
grep -q -- '--enable-nvenc' "$D/strings"; ! grep -q -- 'fdkaac' "$D/strings"; rm -rf "$D"
echo TEST-BUILD-OK
