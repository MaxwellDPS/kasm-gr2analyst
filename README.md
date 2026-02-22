# KASM Workspace – GR2Analyst (Wine)

A [KASM Workspaces](https://kasmweb.com) Docker image that runs **GR2Analyst** (Gibson Ridge NEXRAD Level II radar analysis software) on Linux via Wine. Access a fully functional radar workstation from any web browser.

## Features

- **GR2Analyst** installed via Wine in a 32-bit Windows 10 prefix
- **Pre-configured** Iowa State free Level 2 polling feed
- **Community color tables** for Reflectivity, Velocity, and Correlation Coefficient
- **Curated placefile list** with PlacefileNation and RedTeamWx URLs
- **GPU pass-through** support – works with NVIDIA GPUs or falls back to Mesa llvmpipe software rendering
- **Working internet** – polling, warnings, and placefile downloads work out of the box
- **Wine D3D optimisations** – registry tweaks for Shader Model 2.0+ via OpenGL, font smoothing, and VNC-friendly rendering

## Quick Start (Standalone)

```bash
# Software rendering (no GPU needed)
docker run --rm -it --shm-size=512m -p 6901:6901 \
  -e VNC_PW=password \
  ghcr.io/<your-user>/kasm-gr2analyst:latest

# With NVIDIA GPU pass-through
docker run --rm -it --shm-size=512m --gpus all \
  -e VNC_PW=password -p 6901:6901 \
  -e LIBGL_ALWAYS_SOFTWARE=0 \
  ghcr.io/<your-user>/kasm-gr2analyst:latest
```

Then open **https://localhost:6901** in your browser.

## Using with KASM Workspaces

1. Push the image to your registry (GHCR, Docker Hub, or private)
2. In the KASM admin panel, go to **Workspaces → Add Workspace**
3. Point the Docker Image field to your image tag
4. Set `--shm-size=512m` in Docker Run Config Override
5. For GPU: enable GPU pass-through in the KASM agent/zone config

## Pre-Configured Settings

### Radar Polling
The Iowa State free Level 2 feed is pre-configured:
```
https://mesonet-nexrad.agron.iastate.edu/level2/raw/
```
For higher reliability during severe weather, consider [AllisonHouse](https://allisonhouse.com) ($11.99+/month).

### Color Tables
Three enhanced color tables are included in the `ColorTables/` directory:

| File | Product | Description |
|------|---------|-------------|
| `Enhanced_Reflectivity.pal` | BR | High-contrast reflectivity with clear severe thresholds |
| `Enhanced_Velocity.pal` | BV | Extended range velocity for rotation detection |
| `Correlation_Coefficient.pal` | CC | Dual-pol CC for debris/hail/mixed-phase identification |

To add more, download `.pal` files from [GRLevelX Users Color Tables](https://grlevelxusers.com/grlevelx-goodies/categories/color-tables/) or [RedTeamWx](http://redteamwx.com/grlevelx.html) and drop them into the install directory.

### Placefiles
A curated list of free community placefile URLs is at `placefiles.txt` inside the install directory. Open **Windows → Show Placefile Manager** in GR2Analyst and paste URLs from that list.

### Display Defaults
- Startup site: **KFWS** (Dallas-Fort Worth) – change via Site → Settings
- Background map, state/county outlines, roads, city labels: **enabled**
- Warnings, storm tracks, hail/meso/TVS/LSR icons: **enabled**
- Dark background for radar contrast
- GIS overlay colours optimised for readability

## GPU / Graphics Notes

GR2Analyst requires **Shader Model 2.0** (Direct3D 9). Wine translates this to OpenGL or Vulkan.

| Scenario | What happens |
|----------|-------------|
| No GPU mounted | Mesa llvmpipe software rendering (slow but functional) |
| `--gpus all` with NVIDIA | Hardware-accelerated OpenGL via NVIDIA driver |
| DRI render node (`/dev/dri`) | Hardware-accelerated OpenGL via Mesa |

To switch Wine's D3D backend to Vulkan (if your GPU supports it), run inside the container:
```bash
wine reg add "HKCU\Software\Wine\Direct3D" /v renderer /t REG_SZ /d vulkan /f
```

## Building Locally

```bash
git clone <this-repo>
cd kasm-gr2analyst
docker build \
  --build-arg BASE_TAG=develop \
  --build-arg BASE_IMAGE=core-ubuntu-jammy \
  -t kasm-gr2analyst:local .
```

> The build downloads Wine, .NET 4.8, and the GR2Analyst installer. Expect ~15-25 minutes and a final image of ~4-6 GB.

## Licensing

- **GR2Analyst** is proprietary software by [Gibson Ridge Software](https://grlevelx.com). It includes a 21-day free trial. After the trial, you must purchase a licence key ($250 for v3).
- **This Docker image** and all supporting scripts/config files are provided as-is under the MIT licence.
- **KASM core images** are © Kasm Technologies and subject to their licence terms.

## Project Structure

```
├── Dockerfile                          # Main build file
├── .dockerignore
├── .github/
│   └── workflows/
│       └── build.yml                   # GitHub Actions CI
├── src/ubuntu/install/
│   ├── gr2analyst/
│   │   ├── install_gr2analyst.sh       # Download & silent install
│   │   ├── launch_gr2analyst.sh        # Runtime launch wrapper
│   │   ├── gr2analyst.desktop          # XFCE desktop shortcut
│   │   ├── gr2analyst_settings.reg     # Pre-config registry
│   │   ├── placefiles.txt              # Community placefile URLs
│   │   └── color_tables/
│   │       ├── Enhanced_Reflectivity.pal
│   │       ├── Enhanced_Velocity.pal
│   │       └── Correlation_Coefficient.pal
│   └── wine_override/
│       └── wine_d3d.reg                # Wine D3D/display tweaks
└── README.md
```
