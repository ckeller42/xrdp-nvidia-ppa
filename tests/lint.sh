#!/bin/bash
# Lint (shellcheck) our own scripts (Debian's vendored packaging/xrdp, packaging/xorgxrdp excluded).
set -euo pipefail; cd "$(dirname "$0")/.."
shellcheck -S warning build-source.sh test-build.sh tests/*.sh tests/unit/*.sh \
  packaging/xrdp-desktop-sessions/files/nvidia/xrdp-nvidia-configure \
  packaging/xrdp-desktop-sessions/files/gnome/xrdp-gnome-session \
  packaging/xrdp-desktop-sessions/files/gnome/add-remote-user \
  packaging/xrdp-desktop-sessions/debian/*.postinst packaging/xrdp-desktop-sessions/debian/*.postrm \
  packaging/xrdp-desktop-sessions/debian/*.prerm
echo LINT-OK
