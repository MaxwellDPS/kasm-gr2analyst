#!/usr/bin/env bash
###############################################################################
# custom_startup.sh – KASM custom startup script
#
# Called by the KASM entrypoint after the desktop environment is ready.
# Launches GR2Analyst automatically so users see radar data immediately.
###############################################################################

# Wait briefly for the desktop to be fully ready
sleep 3

# Launch GR2Analyst in the background so this script can exit
/usr/local/bin/launch_gr2analyst.sh &
