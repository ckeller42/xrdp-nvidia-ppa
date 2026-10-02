#!/bin/bash
# Build the test-only FreeRDP client with OpenH264 into work/freerdp (Ubuntu's freerdp3 has no H.264).
set -euo pipefail
W=$(cd "$(dirname "$0")/.." && pwd)/work; mkdir -p "$W"
[ -d "$W/FreeRDP" ] || git clone -q --depth 1 -b 3.32.0 https://github.com/FreeRDP/FreeRDP.git "$W/FreeRDP"
cmake -S "$W/FreeRDP" -B "$W/FreeRDP/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$W/freerdp" \
  -DWITH_OPENH264=ON -DWITH_FFMPEG=OFF -DWITH_SWSCALE=OFF -DWITH_DSP_FFMPEG=OFF -DWITH_CLIENT_SDL=OFF -DWITH_CLIENT_SDL2=OFF \
  -DWITH_CLIENT_SDL3=OFF -DWITH_SERVER=OFF -DWITH_SHADOW=OFF -DWITH_PROXY=OFF -DWITH_SAMPLE=OFF -DWITH_MANPAGES=OFF -DWITH_CUPS=OFF \
  -DWITH_FUSE=OFF -DWITH_WAYLAND=OFF -DCHANNEL_URBDRC=OFF -DWITH_PCSC=OFF -DWITH_WEBVIEW=OFF -DWITH_KRB5=OFF -DWITH_JSON_DISABLED=ON \
  -DBUILD_TESTING=OFF -DWITH_ALSA=OFF -DWITH_FAAD2=OFF -DWITH_FAAC=OFF >/dev/null
cmake --build "$W/FreeRDP/build" -j"$(nproc)" >/dev/null && cmake --install "$W/FreeRDP/build" >/dev/null
echo "test client: $W/freerdp/bin/xfreerdp"
