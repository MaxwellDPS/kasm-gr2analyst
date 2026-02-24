###############################################################################
# KASM Workspace Image: GR2Analyst (via Wine)
#
# GR2Analyst is a Windows-only NEXRAD Level II radar analysis application
# by Gibson Ridge Software. This image runs it under Wine on an Ubuntu
# Jammy KASM core desktop with:
#   - Wine Stable (32-bit prefix, Windows 10 mode)
#   - Mesa/llvmpipe software rendering (works headless; pass through GPU
#     via --gpus all for hardware-accelerated D3D9→OpenGL/Vulkan)
#   - Pre-configured Iowa State free Level 2 polling feed
#   - Community color tables & placefiles baked in
#   - Working internet (uses system DNS/networking)
###############################################################################

ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-jammy"
FROM kasmweb/${BASE_IMAGE}:${BASE_TAG}

USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=${STARTUPDIR}/install
WORKDIR ${HOME}

###############################################################################
# 0. Environment
###############################################################################
ENV DEBIAN_FRONTEND=noninteractive \
    WINEPREFIX=/home/kasm-default-profile/.wine \
    WINEARCH=win32 \
    WINEDEBUG=-all \
    # Disable Gecko/Mono prompts during prefix creation
    WINEDLLOVERRIDES="mscoree=d;mshtml=d" \
    # Mesa llvmpipe fallback when no GPU is mounted
    LIBGL_ALWAYS_SOFTWARE=1 \
    # Required for Wine/wineserver during Docker build
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    # Virtual display for headless Wine operations during build
    DISPLAY=:99 \
    # GR2Analyst install path inside the Wine prefix
    GR2A_INSTALL_DIR="C:\\Program Files\\GRLevelX\\GR2Analyst_2" \
    GR2A_INSTALL_DIR_UNIX="/home/kasm-default-profile/.wine/drive_c/Program Files/GRLevelX/GR2Analyst_2"

###############################################################################
# 1. System dependencies – Wine, Mesa, fonts, networking
###############################################################################
RUN dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget gnupg2 software-properties-common ca-certificates \
        cabextract unzip xz-utils curl && \
    # ── WineHQ repo ──
    wget -qO /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key && \
    echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] \
        https://dl.winehq.org/wine-builds/ubuntu/ jammy main" \
        > /etc/apt/sources.list.d/winehq.list && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    # ── Mesa / llvmpipe for software 3-D when no GPU is passed through ──
    apt-get install -y --no-install-recommends \
        mesa-utils \
        libgl1-mesa-dri:i386 \
        libgl1-mesa-glx:i386 \
        libegl1-mesa:i386 \
        libglu1-mesa:i386 \
        # 32-bit Vulkan ICD loader (for DXVK / VKD3D if user opts in)
        libvulkan1:i386 \
        mesa-vulkan-drivers:i386 \
        # Core fonts & networking
        fonts-liberation fonts-dejavu-core \
        dnsutils iputils-ping net-tools iproute2 \
        # Virtual framebuffer for headless Wine installs during build
        xvfb && \
    # ── Winetricks (latest from GitHub) ──
    wget -qO /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
    # ── Cleanup ──
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# 2. Initialise the Wine prefix & install runtime requirements
#    Split into separate layers for better Docker cache utilisation.
###############################################################################
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    echo ">>> Creating 32-bit Wine prefix …" && \
    wineboot --init && \
    wineserver --wait && \
    winetricks -q win10 && \
    wineserver --wait && \
    echo ">>> Wine prefix ready."

# DirectX libraries (d3dx9, d3dcompiler)
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    winetricks -q d3dx9 d3dcompiler_43 d3dcompiler_47 && \
    wineserver --wait

# Visual C++ runtime – the vc_redist.x86.exe installer often exits 130
# under Wine in CI, but winetricks extracts the critical DLLs via
# cabextract before running the installer, so we tolerate the failure.
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    { winetricks -q vcrun2019 || echo "vcrun2019 installer exited non-zero (expected in CI)"; } && \
    wineserver --wait && \
    ls -la "${WINEPREFIX}/drive_c/windows/system32/msvcp140.dll" && \
    echo "vcrun2019 DLLs verified OK"

# .NET Framework 4.8 (largest component)
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    winetricks -q dotnet48 && \
    wineserver --wait

# Fonts
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    winetricks -q corefonts allfonts && \
    wineserver --wait

###############################################################################
# 3. Wine display / D3D registry tweaks for headless + KasmVNC rendering
###############################################################################
COPY src/ubuntu/install/wine_override/wine_d3d.reg /tmp/wine_d3d.reg
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    wine regedit /tmp/wine_d3d.reg && \
    wineserver --wait && \
    rm /tmp/wine_d3d.reg

###############################################################################
# 4. Download & install GR2Analyst (21-day trial – user supplies their key)
#    The installer is from grlevelx.com and runs silently under Wine.
###############################################################################
COPY src/ubuntu/install/gr2analyst/install_gr2analyst.sh ${INST_SCRIPTS}/gr2analyst/
RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    chmod +x ${INST_SCRIPTS}/gr2analyst/install_gr2analyst.sh && \
    bash ${INST_SCRIPTS}/gr2analyst/install_gr2analyst.sh && \
    rm -rf ${INST_SCRIPTS}/gr2analyst/

###############################################################################
# 5. Pre-configure GR2Analyst settings, color tables, placefiles
###############################################################################
COPY src/ubuntu/install/gr2analyst/color_tables/ \
     "${GR2A_INSTALL_DIR_UNIX}/ColorTables/"
COPY src/ubuntu/install/gr2analyst/gr2analyst_settings.reg /tmp/gr2analyst_settings.reg
COPY src/ubuntu/install/gr2analyst/placefiles.txt /tmp/placefiles.txt

RUN mkdir -p /tmp/runtime-root && \
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 & \
    sleep 1 && \
    wine regedit /tmp/gr2analyst_settings.reg && \
    wineserver --wait && \
    # Copy placefiles list into the install directory for reference / first-run script
    cp /tmp/placefiles.txt "${GR2A_INSTALL_DIR_UNIX}/placefiles.txt" && \
    rm /tmp/gr2analyst_settings.reg /tmp/placefiles.txt

###############################################################################
# 6. Desktop entry & launch wrapper
###############################################################################
COPY src/ubuntu/install/gr2analyst/launch_gr2analyst.sh /usr/local/bin/launch_gr2analyst.sh
COPY src/ubuntu/install/gr2analyst/gr2analyst.desktop \
     ${HOME}/Desktop/gr2analyst.desktop
RUN chmod +x /usr/local/bin/launch_gr2analyst.sh ${HOME}/Desktop/gr2analyst.desktop && \
    { cp /usr/share/backgrounds/bg_kasm.png /usr/share/backgrounds/bg_default.png 2>/dev/null || true; }

###############################################################################
# 7. Reset build-only env vars before runtime
#    DISPLAY and XDG_RUNTIME_DIR were set for the Xvfb used during build;
#    at runtime KASM's entrypoint manages these itself.
###############################################################################
ENV DISPLAY="" \
    XDG_RUNTIME_DIR=""

###############################################################################
# 8. Clean up build-time Xvfb lock files & runtime dir
#    The Xvfb :99 instances used during build leave behind lock files that
#    make KasmVNC think display :99 is already taken.
###############################################################################
RUN rm -f /tmp/.X99-lock && rm -rf /tmp/.X11-unix/X99 /tmp/runtime-root

###############################################################################
# 9. Copy default profile so persistent-profile feature works
###############################################################################
RUN chown -R 1000:0 ${HOME} && \
    find ${HOME} -type d -exec chmod 770 {} + && \
    find ${HOME} -type f -exec chmod 660 {} +

ENV HOME=/home/kasm-user
WORKDIR ${HOME}
USER 1000

###############################################################################
# NOTES FOR USERS
# ─────────────────────────────────────────────────────────────────────────────
# • Stand-alone run (no Kasm orchestrator):
#     docker run --rm -it --shm-size=512m -p 6901:6901 \
#       -e VNC_PW=password <image>
#   Then open https://localhost:6901 in a browser.
#
# • For GPU pass-through (NVIDIA):
#     docker run --rm -it --shm-size=512m --gpus all \
#       -e VNC_PW=password -p 6901:6901 \
#       -e LIBGL_ALWAYS_SOFTWARE=0 <image>
#
# • GR2Analyst is proprietary shareware with a 21-day trial.
#   After the trial, enter your licence key inside the application.
#
# • The Iowa State free Level 2 feed is pre-configured.
#   For higher reliability during severe weather, consider AllisonHouse.
###############################################################################
