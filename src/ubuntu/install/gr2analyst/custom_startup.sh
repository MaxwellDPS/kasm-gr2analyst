#!/usr/bin/env bash
###############################################################################
# custom_startup.sh – KASM custom startup script
#
# Called by the KASM entrypoint after the desktop environment is ready.
# Launches GR2Analyst full-screen automatically.
###############################################################################

# Wait for the desktop to be fully ready
sleep 3

# Launch GR2Analyst in the background
/usr/local/bin/launch_gr2analyst.sh &

# Wait for the GR2Analyst window to appear, then maximize it
for i in $(seq 1 30); do
    sleep 2
    if wmctrl -l 2>/dev/null | grep -qi "gr2analyst\|grlevelx"; then
        wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz 2>/dev/null || true
        echo "[Startup] GR2Analyst window maximized."
        break
    fi
done &
