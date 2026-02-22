#!/usr/bin/env bash
###############################################################################
# install_gr2analyst.sh
# Downloads and silently installs GR2Analyst 3 into the Wine prefix.
# Falls back to v2 if the v3 installer is unavailable.
###############################################################################
set -euo pipefail

GR2A_V3_URL="http://grlevelx.com/downloads/gr2analyst_3_setup.exe"
GR2A_V2_URL="http://grlevelx.com/downloads/gr2analyst_2_setup.exe"
INSTALLER="/tmp/gr2analyst_setup.exe"

echo ">>> Downloading GR2Analyst installer …"
if wget -q --timeout=60 -O "${INSTALLER}" "${GR2A_V3_URL}"; then
    echo "    Got v3 installer."
elif wget -q --timeout=60 -O "${INSTALLER}" "${GR2A_V2_URL}"; then
    echo "    v3 unavailable – fell back to v2 installer."
else
    echo "!!! Could not download GR2Analyst from grlevelx.com."
    echo "    Place the installer manually at ${INSTALLER} and rebuild."
    exit 1
fi

echo ">>> Running GR2Analyst installer (silent) …"
# Inno Setup /VERYSILENT suppresses all UI; /NORESTART skips reboot prompt;
# /SP- suppresses "Setup will install…" confirmation.
xvfb-run wine "${INSTALLER}" /VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES || true
wineserver --wait

echo ">>> Verifying installation …"
INSTALL_DIR="${WINEPREFIX}/drive_c/Program Files/GRLevelX"
if [ -d "${INSTALL_DIR}" ]; then
    echo "    ✓ GR2Analyst installed at: ${INSTALL_DIR}"
    ls -la "${INSTALL_DIR}/"
else
    # Some versions install to a slightly different path
    ALT_DIR="${WINEPREFIX}/drive_c/Program Files/GR2Analyst"
    ALT_DIR2="${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst_2"
    ALT_DIR3="${WINEPREFIX}/drive_c/Program Files/GRLevelX/GR2Analyst"
    for d in "${ALT_DIR}" "${ALT_DIR2}" "${ALT_DIR3}"; do
        if [ -d "$d" ]; then
            echo "    ✓ GR2Analyst installed at: $d"
            ls -la "$d/"
            break
        fi
    done
fi

# Create the custom ColorTables directory if it doesn't already exist
mkdir -p "${INSTALL_DIR}/GR2Analyst_2/ColorTables" 2>/dev/null || true
mkdir -p "${INSTALL_DIR}/GR2Analyst/ColorTables" 2>/dev/null || true

# Clean up
rm -f "${INSTALLER}"
echo ">>> GR2Analyst install complete."
