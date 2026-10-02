#!/bin/bash
# Unit test for xrdp-gnome-session (x-session-manager wrapper): per-user first-login tweaks and the
# environment it hands to gnome-session. Uses a temp HOME, a fake /etc/xdg and a stub gnome-session.
set -euo pipefail; here=$(cd "$(dirname "$0")" && pwd)
tool=${1:-$here/../../packaging/xrdp-desktop-sessions/files/gnome/xrdp-gnome-session}
T=$(mktemp -d); mkdir -p "$T/home" "$T/xdg/autostart" "$T/bin"
touch "$T/xdg/autostart/pop-app-folders.desktop"          # Pop autostart present, transition notice absent
printf '#!/bin/sh\nenv > "%s/env"; echo "$@" > "%s/args"\n' "$T" "$T" > "$T/bin/gnome-session"; chmod +x "$T/bin/gnome-session"
run() { env -i HOME="$T/home" PATH="$T/bin:/usr/bin:/bin" XRDP_GNOME_SESSION_SYSXDG="$T/xdg" "$tool"; }
run
grep -q '^Hidden=true$' "$T/home/.config/autostart/pop-app-folders.desktop"
test ! -e "$T/home/.config/autostart/org.pop_os.transition.Notify.desktop"   # only for autostarts that exist
test -e "$T/home/.local/share/gnome-shell/lock-warning-shown"
grep -qx 'XDG_SESSION_TYPE=x11' "$T/env"; grep -qx 'XDG_CURRENT_DESKTOP=ubuntu:GNOME' "$T/env"
grep -qx 'GNOME_SHELL_SESSION_MODE=ubuntu' "$T/env"; grep -qx 'XCURSOR_THEME=Yaru' "$T/env"
grep -qx -- '--session=ubuntu' "$T/args"
# a user's own override is kept
echo 'Hidden=false' > "$T/home/.config/autostart/pop-app-folders.desktop"; run
grep -qx 'Hidden=false' "$T/home/.config/autostart/pop-app-folders.desktop"
rm -rf "$T"; echo GNOME-SESSION-SCRIPT-OK
