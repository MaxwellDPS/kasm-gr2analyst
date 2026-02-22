# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KASM Workspace Docker image that runs GR2Analyst (Windows-only NEXRAD Level II radar analysis software) on Linux via Wine. Users access the application through a web browser via KasmVNC.

## Build & Test Commands

**Build the Docker image locally:**
```bash
docker build \
  --build-arg BASE_TAG=develop \
  --build-arg BASE_IMAGE=core-ubuntu-jammy \
  -t kasm-gr2analyst:local .
```

**Run standalone (software rendering):**
```bash
docker run --rm -it --shm-size=512m -p 6901:6901 \
  -e VNC_PW=password kasm-gr2analyst:local
```

**Lint the Dockerfile:**
```bash
docker run --rm -i hadolint/hadolint hadolint --ignore DL3008 --ignore DL3003 --ignore DL3015 --ignore SC2086 - < Dockerfile
```

There is no unit test suite. CI runs Hadolint, builds the image, then runs a smoke test that verifies Wine, the GR2Analyst binary, and color table files exist inside the container.

## Architecture

The project is infrastructure-only (Dockerfile + shell scripts + config files). There is no application source code.

**Dockerfile stages (sequential):**
1. System deps — Wine Stable, Mesa/llvmpipe, fonts, winetricks
2. Wine prefix init — 32-bit Win10 prefix with d3dx9, vcrun2019, dotnet48
3. Wine D3D registry tweaks — OpenGL renderer settings for VNC streaming (`wine_d3d.reg`)
4. GR2Analyst silent install — downloads from grlevelx.com, tries v3 then falls back to v2
5. Pre-configuration — registry settings, color tables, placefiles
6. Desktop entry + launch wrapper

**Key files:**
- `src/ubuntu/install/gr2analyst/install_gr2analyst.sh` — downloads and silently installs GR2Analyst via Wine (Inno Setup `/VERYSILENT`)
- `src/ubuntu/install/gr2analyst/launch_gr2analyst.sh` — runtime wrapper that detects GPU, initializes Wine prefix if needed, finds the exe across multiple possible install paths, and launches via `wine`
- `src/ubuntu/install/gr2analyst/gr2analyst_settings.reg` — pre-configures polling source (Iowa State free feed), startup radar site (KFWS), map overlays, hail algorithm thresholds
- `src/ubuntu/install/wine_override/wine_d3d.reg` — Wine Direct3D tuning (OpenGL renderer, shader model, GLSL, FBO offscreen, 256MB VRAM)
- `src/ubuntu/install/gr2analyst/color_tables/*.pal` — custom color tables for Reflectivity, Velocity, and Correlation Coefficient radar products

**Environment variables set in the image:**
- `WINEPREFIX=/home/kasm-default-profile/.wine`, `WINEARCH=win32`, `WINEDEBUG=-all`
- `LIBGL_ALWAYS_SOFTWARE=1` (overridden at runtime if GPU detected)
- `GR2A_INSTALL_DIR` / `GR2A_INSTALL_DIR_UNIX` — Wine and Unix paths to the GR2Analyst install directory

## CI/CD

GitHub Actions workflow at `.github/workflows/build.yml`:
- Triggers on push to `main`/`develop` and PRs to `main`
- **Lint job**: Hadolint with ignored rules DL3008, DL3003, DL3015, SC2086
- **Build job**: Docker Buildx with GHA layer caching; pushes to GHCR on main branch
- **Smoke test job**: pulls the built image and verifies Wine version, GR2Analyst binary presence, color table files, and network connectivity

## Important Conventions

- The Wine prefix is 32-bit (`win32`) — GR2Analyst is a 32-bit Windows application
- Install paths vary between GR2Analyst versions; both the installer script and launch wrapper check multiple candidate directories
- The launch wrapper auto-detects GPU (NVIDIA via `nvidia-smi`, then DRI render node) and falls back to Mesa llvmpipe software rendering
- Registry files (`.reg`) use Windows registry format and are applied via `wine regedit`
- The base image is `kasmweb/core-ubuntu-jammy` which provides the KASM desktop environment and KasmVNC
