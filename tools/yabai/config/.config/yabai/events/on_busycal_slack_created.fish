#!/usr/bin/env fish

# Event handler for BusyCal/Slack window creation
# Resizes BusyCal when both apps are present on the work space

set lib_dir "$HOME/.config/yabai/lib"
source "$lib_dir/windows.fish"

echo "[BusyCal/Slack Event] Window created, checking resize conditions..."

# Small delay to ensure window is fully initialized and moved to correct space
sleep 0.3

resize_busycal_with_slack
