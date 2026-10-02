# xrdp with NVIDIA NVENC — Ubuntu PPA

[![build](https://github.com/ckeller42/xrdp-nvidia-ppa/actions/workflows/build.yml/badge.svg)](https://github.com/ckeller42/xrdp-nvidia-ppa/actions/workflows/build.yml)

Packaging for **xrdp** and **xorgxrdp** built from upstream `devel` with NVIDIA support, published as
[`ppa:christoph-keller/xrdp-nvidia`](https://launchpad.net/~christoph-keller/+archive/ubuntu/xrdp-nvidia)
for Ubuntu **24.04 (noble)** and **26.04 (resolute)**, amd64.

What you get:
- **GPU-accelerated sessions**: each xrdp session runs Xorg on the real NVIDIA driver (OpenGL/Vulkan on the GPU).
- **H.264 encoded by NVENC** (`xrdp-accel-assist`) for clients using the RDP graphics pipeline (Microsoft Windows App on macOS/Windows).
- Fixes not yet upstream (see `packaging/*/debian/patches/`, forks [ckeller42/xrdp](https://github.com/ckeller42/xrdp) and [ckeller42/xorgxrdp](https://github.com/ckeller42/xorgxrdp)):
  NVENC helper released on disconnect, 60 Hz modes (was 50 fps), cursor transparency for clients that ignore alpha.

## Packages

| Package | Purpose |
|---|---|
| `xrdp`, `xorgxrdp` | the RDP server and its Xorg drivers (NVENC, x264, openh264; local RandR for NVIDIA) |
| `xrdp-nvidia-session` | detects an NVIDIA GPU and configures sessions for it (NVIDIA Xorg config, NVENC). Without NVIDIA it changes nothing. Re-detect: `sudo dpkg-reconfigure xrdp-nvidia-session` |
| `xrdp-gnome-session` | GNOME (Ubuntu session) as the xrdp desktop for new users, remote-friendly defaults (no lock/blank/suspend, no animations), `add-remote-user` |

## Install

```sh
sudo add-apt-repository ppa:christoph-keller/xrdp-nvidia
sudo apt install xrdp xorgxrdp xrdp-nvidia-session xrdp-gnome-session
```

Requirements for GPU sessions: proprietary NVIDIA driver with `nvidia-drm.modeset=1`. `xrdp-gnome-session` registers
GNOME as `x-session-manager`, so every user without an own `~/.xsession` gets it. New users: `sudo add-remote-user <name>`.

Client: **Windows App** (Mac/iPad/Windows), colour quality **High (32 bit)** for H.264. The iPad app has no H.264 and uses RemoteFX.

## Known limits

- One client per session (a second connection as the same user takes the session over).
- About 0.5 GB VRAM per active session.
- Clients that ignore cursor alpha (e.g. Jump Desktop) show a thin shadow outline; set
  `XORGXRDP_CURSOR_ALPHA_CUTOFF=128` under `[SessionVariables]` in `/etc/xrdp/sesman.ini` to drop cursor shadows.

## Development

```sh
pre-commit install          # commit hooks: whitespace/yaml, shellcheck, unit tests (same as CI)
tests/unit/nvidia-detect.sh; tests/unit/gnome-session-script.sh
tests/unit/build-source.sh noble; tests/unit/test-build.sh noble   # full package build (podman)
```

CI (`.github/workflows/build.yml`): pre-commit + unit tests, then source + binary builds for noble and resolute in
clean containers with lintian (errors fail).

## Building

`pins.env` pins upstream commits; `./build-source.sh <series>` builds source packages, `./test-build.sh <series>`
builds them offline in a clean container, `./upload.sh <series>` uploads. CI: test builds on every PR, upload on tags.

## License

`debian/` directories: as in Debian's packaging (MirOS, see `debian/copyright`). Scripts and tests: MIT (`LICENSE`).
