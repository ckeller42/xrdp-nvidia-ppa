#!/bin/bash
# The orig tarball must be byte-identical regardless of the builder's umask (CI: 022, desktop: 002),
# otherwise Launchpad rejects later uploads ("file already exists with different contents").
set -euo pipefail; cd "$(dirname "$0")/../.."; . ./pins.env
o="out/xrdp_${UPSTREAM_VERSION}+git${XRDP_DATE}.${XRDP_COMMIT:0:7}.orig.tar.xz"
h() { rm -f "$o"; (umask "$1"; ./build-source.sh noble >/dev/null 2>&1); sha256sum "$o" | cut -d' ' -f1; }
a=$(h 022); b=$(h 002)
[ "$a" = "$b" ] || { echo "orig differs by umask: 022=$a 002=$b" >&2; exit 1; }
echo "ORIG-REPRODUCIBLE-OK $a"
