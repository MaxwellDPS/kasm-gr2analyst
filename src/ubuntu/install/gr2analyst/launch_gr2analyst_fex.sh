#!/usr/bin/env bash
###############################################################################
# launch_gr2analyst_fex.sh – KASM launch wrapper for GR2Analyst via FEX-Emu
#
# Same logic as launch_gr2analyst.sh but skips GPU detection
# (FEX uses software rendering only).
###############################################################################
set -euo pipefail

export WINEPREFIX="${HOME}/.wine"
export WINEARCH=win32
export WINEDEBUG=-all
export WINE_HOME="${WINE_HOME:-/opt/wine-stable}"
# FEX + Wine uses Mesa llvmpipe software rendering
export LIBGL_ALWAYS_SOFTWARE=1
# Suppress Gecko/Mono popups
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

echo "[GR2Analyst/FEX] Using FEX-Emu for x86 emulation on ARM64."
echo "[GR2Analyst/FEX] Software rendering (Mesa llvmpipe)."

# ── Ensure Wine prefix exists (handles fresh persistent profiles) ────────
if [ ! -d "${WINEPREFIX}/drive_c" ]; then
    echo "[GR2Analyst/FEX] Initialising Wine prefix for new user profile …"
    wineboot --init
    wineserver --wait
fi

# ── Locate the GR2Analyst install directory ──────────────────────────────
GR2A_DIRS=(
    "${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst_3"
    "${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst_2"
    "${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst"
    "${WINEPREFIX}/drive_c/Program Files/GR2Analyst"
)

GR2A_EXE=""
GR2A_DIR=""
for d in "${GR2A_DIRS[@]}"; do
    if [ -f "$d/gr2analyst.exe" ]; then
        GR2A_EXE="$d/gr2analyst.exe"
        GR2A_DIR="$d"
        break
    fi
done

if [ -z "${GR2A_EXE}" ]; then
    echo "!!! GR2Analyst executable not found in any expected location."
    echo "    Searched: ${GR2A_DIRS[*]}"
    echo "    Please verify the installation."
    exit 1
fi

# ── Apply registry settings (every launch) ───────────────────────────────
SETTINGS_REG="/usr/share/gr2analyst/gr2analyst_settings.reg"
if [ -f "${SETTINGS_REG}" ]; then
    echo "[GR2Analyst/FEX] Applying registry settings …"
    wine regedit "${SETTINGS_REG}" 2>/dev/null || true
    wineserver --wait
fi

# ── Sync color tables into install directory ─────────────────────────────
COLOR_SRC="/usr/share/gr2analyst/color_tables"
if [ -d "${COLOR_SRC}" ]; then
    mkdir -p "${GR2A_DIR}/ColorTables"
    cp -u "${COLOR_SRC}"/*.pal "${GR2A_DIR}/ColorTables/" 2>/dev/null || true
fi

# ── Copy placefiles reference if not present ─────────────────────────────
PLACEFILES_SRC="/usr/share/gr2analyst/placefiles.txt"
if [ -f "${PLACEFILES_SRC}" ] && [ ! -f "${GR2A_DIR}/placefiles.txt" ]; then
    cp "${PLACEFILES_SRC}" "${GR2A_DIR}/placefiles.txt"
fi

# ── Launch ───────────────────────────────────────────────────────────────
echo "[GR2Analyst/FEX] Launching: ${GR2A_EXE}"
cd "${GR2A_DIR}"
exec wine "${GR2A_EXE}" "$@"
