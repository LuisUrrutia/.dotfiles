#!/usr/bin/env fish

# Debounce (yabai#259): macOS fires display_removed multiple times rapidly when
# a monitor disconnects. Use a lockfile so only the first handler does work.
set -l lockfile /tmp/yabai_display_removed.lock

if test -f $lockfile
    # Check if lockfile is stale (older than 5 seconds)
    set -l lock_age (math (date +%s) - (stat -f %m $lockfile))
    if test $lock_age -lt 5
        echo "[Display Removed] Debounced — another handler is already running"
        exit 0
    end
end

touch $lockfile

# Save window layout BEFORE moving spaces — the retile will reset BSP ratios
set lib_dir "$HOME/.config/yabai/lib"
source "$lib_dir/windows.fish"
save_layout

echo "[Display Removed] Consolidating spaces to main display..."
# Move all labeled spaces to display 1 (main display), skip unlabeled ones
for space_label in (yabai -m query --spaces | jq -r '.[] | select(.label != "") | .label')
    yabai -m space "$space_label" --display 1 2>/dev/null; or true
end
echo "[Display Removed] All spaces moved to main display"

# Update expected display count so on_system_woke.fish stays accurate
yabai -m query --displays | jq 'length' > /tmp/yabai_expected_displays

rm -f $lockfile
