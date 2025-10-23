#!/usr/bin/env fish

# $YABAI_DISPLAY_ID, $YABAI_DISPLAY_INDEX
# Get the number of displays
set SPACE_ARRANGEMENTS $argv[1]
set DISPLAY_INDEX $YABAI_DISPLAY_INDEX

echo "[Display Added] Added Display $DISPLAY_INDEX"

if test -z "$SPACE_ARRANGEMENTS"
    echo "[Display Added] No space arrangements provided, exiting."
    exit 0
end

set spaces (echo $SPACE_ARRANGEMENTS | string split ",")
for space in $spaces
    if test -z "$space"
        continue
    end

    set parts (string split '|' $space)
    set space_label $parts[1]
    set preferred_display $parts[2]

    if test "$preferred_display" = "$DISPLAY_INDEX"
        echo "[Display Added] Moving space $space_label to display $DISPLAY_INDEX"
        yabai -m space "$space_label" --display $DISPLAY_INDEX 2>/dev/null; or true
    end
end