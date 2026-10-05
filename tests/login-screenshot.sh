#!/bin/bash
# Screenshot of the xrdp login screen as a client without saved credentials sees it.
# Usage: login-screenshot.sh OUT.xwd [PORT=3389]   (needs xvfb, x11-apps; view/convert the xwd elsewhere)
set -uo pipefail
F=$(cd "$(dirname "$0")/.." && pwd)/work/freerdp
XFREERDP=${XFREERDP:-$F/bin/xfreerdp}; export LD_LIBRARY_PATH=$F/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
OUT=$1 PORT=${2:-3389}
xvfb-run -a -s "-screen 0 1280x800x24" bash -c "
  '$XFREERDP' /v:127.0.0.1:$PORT /cert:ignore /size:1280x800 /gfx:AVC444:on /sec:tls /u:skeller /d: /p: >/dev/null 2>&1 &
  sleep 8; xwd -root -silent -out '$OUT'; kill %1" 2>/dev/null
[ -s "$OUT" ]
