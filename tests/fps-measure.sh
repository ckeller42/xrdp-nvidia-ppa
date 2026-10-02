#!/bin/bash
# Measure NVENC frames/s of one xrdp session under load (glxgears) — prints avg fps and avg GPU util.
# Usage: fps-measure.sh USER PASS [MIN_FPS=55] — exit 0 only if the average of non-zero samples >= MIN_FPS
# (nvidia-smi reports 0 for some 3 s windows; those gaps are ignored).
set -uo pipefail
U=$1 P=$2 MIN=${3:-55}; dir=$(dirname "$0")
"$dir/rdp-smoke.sh" "$U" "$P" 3389 avc444 50 >/dev/null 2>&1 &
sleep 10
X=$(pgrep -u "$U" -a Xorg | grep -oE ' :[0-9]+' | head -1 | tr -d ' ')
A=$(pgrep -u "$U" -a Xorg | grep -oE '\-auth [^ ]+' | head -1 | cut -d' ' -f2)
sudo -u "$U" env DISPLAY=$X XAUTHORITY=$A vblank_mode=0 __GL_SYNC_TO_VBLANK=0 glxgears -geometry 1200x700 >/dev/null 2>&1 &
sleep 5
nvidia-smi --query-gpu=encoder.stats.averageFps,utilization.gpu --format=csv,noheader,nounits -l 3 2>/dev/null | head -10 > /tmp/fps-samples.txt
sudo pkill -u "$U" glxgears; wait
awk -F', ' -v min="$MIN" '$1>0 {f+=$1; n++} {g+=$2; m++} END {a=(n?f/n:0); printf "avg_fps=%.1f avg_gpu_util=%.0f%% nonzero_samples=%d min=%s\n", a, g/m, n, min; exit !(a>=min)}' /tmp/fps-samples.txt
