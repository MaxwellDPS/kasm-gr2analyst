#!/usr/bin/env bash
###############################################################################
# launch_gr2analyst.sh – KASM launch wrapper for GR2Analyst under Wine
###############################################################################
set -euo pipefail

export WINEPREFIX="${HOME}/.wine"
export WINEARCH=win32
export WINEDEBUG=-all
# Fall back to software rendering if no GPU is detected
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
# Suppress Gecko/Mono popups
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

# ── Detect GPU availability and adjust renderer ──────────────────────────
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    echo "[GR2Analyst] NVIDIA GPU detected – using hardware rendering."
    export LIBGL_ALWAYS_SOFTWARE=0
elif [ -e /dev/dri/renderD128 ]; then
    echo "[GR2Analyst] DRI render node detected – using hardware rendering."
    export LIBGL_ALWAYS_SOFTWARE=0
else
    echo "[GR2Analyst] No GPU detected – using Mesa llvmpipe (software)."
fi

# ── Ensure Wine prefix exists (handles fresh persistent profiles) ────────
if [ ! -d "${WINEPREFIX}/drive_c" ]; then
    echo "[GR2Analyst] Initialising Wine prefix for new user profile …"
    wineboot --init
    wineserver --wait
fi

# ── Locate the GR2Analyst executable ─────────────────────────────────────
GR2A_PATHS=(
    "${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst_3/gr2analyst.exe"
    "${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst_2/gr2analyst.exe"
    "${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst/gr2analyst.exe"
    "${WINEPREFIX}/drive_c/Program Files/GR2Analyst/gr2analyst.exe"
)

GR2A_EXE=""
for p in "${GR2A_PATHS[@]}"; do
    if [ -f "$p" ]; then
        GR2A_EXE="$p"
        break
    fi
done

if [ -z "${GR2A_EXE}" ]; then
    echo "!!! GR2Analyst executable not found in any expected location."
    echo "    Searched: ${GR2A_PATHS[*]}"
    echo "    Please verify the installation."
    # Open a terminal so the user can debug
    exec xfce4-terminal --title "GR2Analyst – Not Found" \
        -e "bash -c 'echo GR2Analyst not found.; echo Check Wine prefix at ${WINEPREFIX}; bash'"
fi

echo "[GR2Analyst] Launching: ${GR2A_EXE}"
cd "$(dirname "${GR2A_EXE}")"
exec wine "${GR2A_EXE}" "$@"
