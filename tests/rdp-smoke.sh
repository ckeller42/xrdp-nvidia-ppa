#!/bin/bash
# RDP smoke test: connect with FreeRDP (inside Xvfb), hold, disconnect, check NVENC helper cleanup.
# Usage: rdp-smoke.sh USER PASS [PORT=3389] [GFX=avc444|avc420|rfx] [SECONDS=15]
# Prints HELPERS_DURING=<n> HELPERS_AFTER=<n> CAPTURE=<H264|RFX|normal|none>; exit 0 only if
# CAPTURE is H264 (RFX for rfx) and no xrdp-accel-assist is left 10 s after disconnect.
set -uo pipefail
# FreeRDP with H.264 (Ubuntu's freerdp3 is built without it); override with $XFREERDP
F=$(cd "$(dirname "$0")/.." && pwd)/work/freerdp
XFREERDP=${XFREERDP:-$F/bin/xfreerdp}; export LD_LIBRARY_PATH=$F/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
U=$1 P=$2 PORT=${3:-3389} GFX=${4:-avc444} T=${5:-15}
uid=$(id -u "$U"); home=$(getent passwd "$U" | cut -d: -f6)
# capture mode = last 'got ... capture' line in the newest Xorg log of this user (Xorg rotates logs to .old)
lastcap() { sudo sh -c "ls -t $home/.xorgxrdp.*.log $home/.local/share/xorg/xorgxrdp.*.log 2>/dev/null | head -1 | xargs -r grep -hoE 'got [A-Za-z0-9]+ capture'" | tail -1 | awk '{print $2}'; }
timeout $((T+20)) xvfb-run -a "$XFREERDP" /v:127.0.0.1:$PORT /u:"$U" /p:"$P" /cert:ignore /size:1280x800 /gfx:${GFX^^}:on /sound:sys:fake >/tmp/rdp-smoke.$U.log 2>&1 &
cp=$!
sleep "$T"
during=$(pgrep -u "$uid" -c -f xrdp-accel-assist)
cap=$(lastcap)
pkill -P $cp 2>/dev/null; kill $cp 2>/dev/null; pkill -f "xfreerdp /v:127.0.0.1:$PORT /u:$U " 2>/dev/null; wait $cp 2>/dev/null
sleep 10
after=$(pgrep -u "$uid" -c -f xrdp-accel-assist)
echo "HELPERS_DURING=$during HELPERS_AFTER=$after CAPTURE=${cap:-none}"
want=H264; [ "$GFX" = rfx ] && want=RFX
[ "${cap:-none}" = "$want" ] && [ "$after" -eq 0 ]
