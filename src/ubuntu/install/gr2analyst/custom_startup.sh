#!/usr/bin/env bash
###############################################################################
# custom_startup.sh – KASM custom startup script
#
# Called by the KASM entrypoint after the desktop environment is ready.
# Hides the XFCE panel and launches GR2Analyst maximized.
###############################################################################

# Wait for the desktop to be fully ready
sleep 3

# Kill the XFCE panel so GR2Analyst gets the full screen
xfce4-panel --quit 2>/dev/null || true
pkill -f xfce4-panel 2>/dev/null || true

# Launch GR2Analyst in the background
/usr/local/bin/launch_gr2analyst.sh &

# Wait for the GR2Analyst window to appear, then maximize it
(
    for i in $(seq 1 60); do
        sleep 2
        # Look for any Wine window
        WIN=$(xdotool search --name "GR2Analyst" 2>/dev/null | head -1)
        if [ -n "$WIN" ]; then
            sleep 2
            # Maximize using wmctrl
            wmctrl -i -r "$WIN" -b add,maximized_vert,maximized_horz 2>/dev/null || true
            # Also try xdotool for fullscreen
            xdotool windowactivate "$WIN" 2>/dev/null || true
            xdotool key --window "$WIN" F11 2>/dev/null || true
            echo "[Startup] GR2Analyst window maximized."
            break
        fi
    done
) &
