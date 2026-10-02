#!/bin/bash
# Cursor AND-mask test: connect with FreeRDP, dump the received pointers (LD_PRELOAD shim) and
# check that fully transparent pixels of 32bpp cursors are also transparent for clients that
# ignore the alpha channel (e.g. Jump Desktop). Usage: cursor-mask.sh USER PASS [PORT=3389] [CUTOFF]
# CUTOFF: also require no pixels with 0 < alpha < CUTOFF (XORGXRDP_CURSOR_ALPHA_CUTOFF active).
set -uo pipefail
U=$1 P=$2 PORT=${3:-3389} CUT=${4:-0}; here=$(cd "$(dirname "$0")" && pwd)
F=$here/../work/freerdp; export LD_LIBRARY_PATH=$F/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
[ -f "$here/cursor/pointer-dump.so" ] || gcc -shared -fPIC -O2 -o "$here/cursor/pointer-dump.so" "$here/cursor/pointer-dump.c" -ldl
D=$(mktemp -d); export PTR_DUMP_DIR=$D
timeout 40 xvfb-run -a env LD_PRELOAD="$here/cursor/pointer-dump.so" "$F/bin/xfreerdp" /v:127.0.0.1:$PORT /u:"$U" /p:"$P" \
  /cert:ignore /size:1280x800 /gfx:AVC444:on >/tmp/cursor-mask.$U.log 2>&1 &
cp=$!; sleep 25; kill $cp 2>/dev/null; pkill -x xfreerdp 2>/dev/null; wait $cp 2>/dev/null
"$here/cursor/analyze.py" "$D" "$CUT"; rc=$?; rm -rf "$D"; exit $rc
