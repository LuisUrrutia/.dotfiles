#!/usr/bin/env fish

# $YABAI_DISPLAY_ID, $YABAI_DISPLAY_INDEX
set SPACE_ARRANGEMENTS $argv[1]
set DISPLAY_INDEX $YABAI_DISPLAY_INDEX

if test -z "$DISPLAY_INDEX"
    echo "[Display Added] Error: YABAI_DISPLAY_INDEX not set" >&2
    exit 1
end

# Debounce (yabai#259): macOS can fire display_added multiple times for the same
# display during wake. Use a per-display lockfile so only the first handler runs.
set -l lockfile /tmp/yabai_display_added_$DISPLAY_INDEX.lock
if test -f $lockfile
    set -l lock_age (math (date +%s) - (stat -f %m $lockfile))
    if test $lock_age -lt 5
        echo "[Display Added] Debounced display $DISPLAY_INDEX — another handler is already running"
        exit 0
    end
end
touch $lockfile

echo "[Display Added] Added Display $DISPLAY_INDEX"

if test -n "$SPACE_ARRANGEMENTS"
    set spaces (string split "," $SPACE_ARRANGEMENTS)
    for space in $spaces
        if test -z "$space"
            continue
        end

        set parts (string split '/' $space)
        set space_label $parts[1]
        set preferred_display $parts[2]

        if test "$preferred_display" = "$DISPLAY_INDEX"
            echo "[Display Added] Moving space $space_label to display $DISPLAY_INDEX"
            yabai -m space "$space_label" --display $DISPLAY_INDEX 2>/dev/null; or true
        end
    end
else
    echo "[Display Added] No space arrangements provided, skipping space moves."
end

# Restore window order and BSP ratios from the snapshot saved by on_display_removed.
# Brief delay to let yabai finish retiling after space moves.
sleep 1
set lib_dir "$HOME/.config/yabai/lib"
source "$lib_dir/windows.fish"
restore_layout

# Update expected display count so on_system_woke.fish stays accurate
yabai -m query --displays | jq 'length' > /tmp/yabai_expected_displays

rm -f $lockfile
