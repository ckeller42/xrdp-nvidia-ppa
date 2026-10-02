#!/bin/bash
# Unit test for xrdp-nvidia-configure: GPU detection, BusID conversion, sesman.ini edits.
# Uses a temp root (--root) and a stub nvidia-smi on PATH. Usage: tests/unit/nvidia-detect.sh [tool]
set -euo pipefail; here=$(cd "$(dirname "$0")" && pwd)
tool=${1:-$here/../../packaging/xrdp-desktop-sessions/files/nvidia/xrdp-nvidia-configure}
S=$(mktemp -d); T=$(mktemp -d)
mk() { local r; r=$(mktemp -d -p "$T"); mkdir -p "$r/etc/xrdp" "$r/etc/X11/xrdp" "$r/proc/driver/nvidia"; cp "$here/fixtures/sesman.ini" "$r/etc/xrdp/"; echo "$r"; }
smi() { printf '#!/bin/sh\n'; for l in "$@"; do printf 'echo %s\n' "$l"; done; }
# 1) NVIDIA, single GPU, hex bus id with domain
R=$(mk); echo "595.84" > "$R/proc/driver/nvidia/version"; smi 00000000:41:00.0 > "$S/nvidia-smi"; chmod +x "$S/nvidia-smi"
PATH=$S:$PATH "$tool" --root "$R" >/dev/null
grep -q 'BusID "PCI:65:0:0"' "$R/etc/X11/xrdp/xorg_nvidia_auto.conf"
grep -q '^param=xrdp/xorg_nvidia_auto.conf$' "$R/etc/xrdp/sesman.ini"
test "$(grep -c '^XRDP_USE_ACCEL_ASSIST=1$' "$R/etc/xrdp/sesman.ini")" = 1
PATH=$S:$PATH "$tool" --root "$R" >/dev/null                       # idempotent
test "$(grep -c '^XRDP_USE_ACCEL_ASSIST=1$' "$R/etc/xrdp/sesman.ini")" = 1
test "$(grep -c '^param=xrdp/xorg_nvidia_auto.conf$' "$R/etc/xrdp/sesman.ini")" = 1
# 2) two GPUs -> first one
R=$(mk); echo x > "$R/proc/driver/nvidia/version"; smi 00000000:0A:00.0 00000000:41:00.0 > "$S/nvidia-smi"
PATH=$S:$PATH "$tool" --root "$R" >/dev/null; grep -q 'BusID "PCI:10:0:0"' "$R/etc/X11/xrdp/xorg_nvidia_auto.conf"
# 3) migration from thinky-remote-desktop's config name
R=$(mk); echo x > "$R/proc/driver/nvidia/version"; smi 00000000:41:00.0 > "$S/nvidia-smi"
sed -i 's|^param=xrdp/xorg.conf$|param=xrdp/xorg_nvidia_thinky.conf|' "$R/etc/xrdp/sesman.ini"
PATH=$S:$PATH "$tool" --root "$R" >/dev/null; grep -q '^param=xrdp/xorg_nvidia_auto.conf$' "$R/etc/xrdp/sesman.ini"
# 4) no NVIDIA -> unchanged, exit 0
R=$(mk); rm -r "$R/proc/driver/nvidia"; cp "$R/etc/xrdp/sesman.ini" "$T/before"
PATH=$S:$PATH "$tool" --root "$R" >/dev/null; cmp "$R/etc/xrdp/sesman.ini" "$T/before"; test ! -e "$R/etc/X11/xrdp/xorg_nvidia_auto.conf"
# 5) driver loaded but nvidia-smi fails -> unchanged, exit 0
R=$(mk); echo x > "$R/proc/driver/nvidia/version"; printf '#!/bin/sh\nexit 9\n' > "$S/nvidia-smi"; cp "$R/etc/xrdp/sesman.ini" "$T/before"
PATH=$S:$PATH "$tool" --root "$R" >/dev/null; cmp "$R/etc/xrdp/sesman.ini" "$T/before"
rm -rf "$S" "$T"; echo NVIDIA-DETECT-OK
