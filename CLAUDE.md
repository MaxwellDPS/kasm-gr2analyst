# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KASM Workspace Docker image that runs GR2Analyst (Windows-only NEXRAD Level II radar analysis software) on Linux via Wine. Users access the application through a web browser via KasmVNC.

## Build & Test Commands

**Build the Docker image locally (x86-64):**
```bash
docker build \
  --build-arg BASE_TAG=develop \
  --build-arg BASE_IMAGE=core-ubuntu-jammy \
  -t kasm-gr2analyst:local .
```

**Build the ARM64 variant (FEX-Emu):**
```bash
docker build --platform linux/arm64 -f Dockerfile.fex \
  --build-arg BASE_TAG=develop \
  --build-arg BASE_IMAGE=core-ubuntu-jammy \
  -t kasm-gr2analyst:fex .
```

**Run standalone (software rendering):**
```bash
docker run --rm -it --shm-size=512m -p 6901:6901 \
  -e VNC_PW=password kasm-gr2analyst:local
```

**Lint the Dockerfiles:**
```bash
docker run --rm -i hadolint/hadolint hadolint --ignore DL3008 --ignore DL3003 --ignore DL3015 --ignore SC2086 --ignore SC2174 --ignore SC2015 - < Dockerfile
docker run --rm -i hadolint/hadolint hadolint --ignore DL3008 --ignore DL3003 --ignore DL3015 --ignore DL3029 --ignore SC2086 --ignore SC2174 --ignore SC2015 - < Dockerfile.fex
```

There is no unit test suite. CI runs Hadolint, builds the image, then runs a smoke test that verifies Wine, the GR2Analyst binary, and color table files exist inside the container.

## Architecture

The project is infrastructure-only (Dockerfile + shell scripts + config files). There is no application source code.

### Two Dockerfile variants

**`Dockerfile`** — primary x86-64 image, single-stage:
1. System deps — Wine Stable, Mesa/llvmpipe, fonts, winetricks
2. Wine prefix init — 32-bit Win10 prefix with d3dx9, vcrun2019, dotnet48
3. Wine D3D registry tweaks — OpenGL renderer settings for VNC streaming (`wine_d3d.reg`)
4. GR2Analyst silent install — downloads from grlevelx.com, tries v3 then falls back to v2
5. Pre-configuration — registry settings, color tables, placefiles
6. Desktop entry + launch wrapper
7. Reset build-time `DISPLAY`/`XDG_RUNTIME_DIR` to KASM runtime defaults (`:1` and `/tmp/runtime-1000`)

**`Dockerfile.fex`** — ARM64 variant using FEX-Emu for x86 JIT translation:
- Multi-stage: first stage pulls an x86-64 Ubuntu rootfs for FEX, second stage builds the ARM64 image
- Installs FEX-Emu and extracts x86 Wine from WineHQ `.deb` packages (not apt-installed) via scripts in `src/ubuntu/install/fex/`
- Creates FEXInterpreter wrapper scripts so `wine`/`wineserver`/`wineboot` transparently run through FEX
- Uses `launch_gr2analyst_fex.sh` instead of `launch_gr2analyst.sh` (no GPU detection; always software rendering)
- Build is significantly slower (~60-90+ min for dotnet48 under emulation)

**Key files:**
- `src/ubuntu/install/gr2analyst/install_gr2analyst.sh` — downloads and silently installs GR2Analyst via Wine (Inno Setup `/VERYSILENT`); tries v3 then falls back to v2, also applies v3 update if available
- `src/ubuntu/install/gr2analyst/launch_gr2analyst.sh` — runtime wrapper that detects GPU, initializes Wine prefix if needed, finds the exe across multiple possible install paths, and launches via `wine`
- `src/ubuntu/install/gr2analyst/launch_gr2analyst_fex.sh` — FEX-Emu variant of the launch wrapper (software rendering only, no GPU detection)
- `src/ubuntu/install/gr2analyst/gr2analyst_settings.reg` — pre-configures polling source (Iowa State free feed), startup radar site (KFWS), map overlays, hail algorithm thresholds
- `src/ubuntu/install/wine_override/wine_d3d.reg` — Wine Direct3D tuning (OpenGL renderer, shader model, GLSL, FBO offscreen, 256MB VRAM)
- `src/ubuntu/install/gr2analyst/color_tables/*.pal` — custom color tables for Reflectivity, Velocity, and Correlation Coefficient radar products
- `src/ubuntu/install/fex/` — FEX-Emu install scripts (`install_fex.sh`, `install_wine_fex.sh`, `wrap_wine_fex.sh`)

**Environment variables set in the image:**
- `WINEPREFIX=/home/kasm-default-profile/.wine`, `WINEARCH=win32`, `WINEDEBUG=-all`
- `LIBGL_ALWAYS_SOFTWARE=1` (overridden at runtime if GPU detected, x86-64 only)
- `GR2A_INSTALL_DIR` / `GR2A_INSTALL_DIR_UNIX` — Wine and Unix paths to the GR2Analyst install directory
- FEX variant adds `FEX_ROOTFS=/opt/fex-rootfs`, `WINE_HOME=/opt/wine-stable`

## CI/CD

Two GitHub Actions workflows:

**`.github/workflows/build.yml`** (x86-64):
- Triggers on push to `main`/`develop` and PRs to `main`
- **Lint job**: Hadolint with ignored rules DL3008, DL3003, DL3015, SC2086, SC2174, SC2015
- **Build job**: Docker Buildx with GHA layer caching; pushes to GHCR on main branch
- **Smoke test job**: pulls the built image and verifies Wine version, GR2Analyst binary presence, color table files, and network connectivity

**`.github/workflows/build-fex.yml`** (ARM64):
- Same trigger rules; builds `Dockerfile.fex` on `ubuntu-24.04-arm` runners
- Additional Hadolint ignore: DL3029 (platform mismatch, expected for cross-arch)
- Smoke test also verifies FEX-Emu is functional

## Important Conventions

- The Wine prefix is 32-bit (`win32`) — GR2Analyst is a 32-bit Windows application
- Install paths vary between GR2Analyst versions; both the installer script and launch wrapper check multiple candidate directories
- The launch wrapper auto-detects GPU (NVIDIA via `nvidia-smi`, then DRI render node) and falls back to Mesa llvmpipe software rendering
- Registry files (`.reg`) use Windows registry format and are applied via `wine regedit`
- The base image is `kasmweb/core-ubuntu-jammy` which provides the KASM desktop environment and KasmVNC
- Each Wine operation in the Dockerfile starts its own `Xvfb :99` and `mkdir -p /tmp/runtime-root` — this is intentional since each `RUN` layer gets a fresh process namespace
- The `vcrun2019` winetricks verb may exit non-zero under Wine in CI; this is tolerated because the critical DLLs are extracted before the installer runs
- Build-time `DISPLAY` and `XDG_RUNTIME_DIR` must be reset before runtime so KASM's entrypoint can manage them
