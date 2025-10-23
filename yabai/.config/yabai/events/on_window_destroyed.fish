#!/usr/bin/env fish

# Source required lib functions
set LIB_DIR "$HOME/.config/yabai/lib"
source "$LIB_DIR/spaces.fish"

set REMOVED_WINDOW_ID $YABAI_WINDOW_ID

set space (yabai -m query --spaces | jq -r ".[] | select(.windows | index($REMOVED_WINDOW_ID)) | \"\(.label) \(.windows | length)\"")
set parts (string split ' ' $space)
set space_label $parts[1]
set window_count $parts[2]

if test -z "$space_label"
    destroy_empty_spaces
    exit 0
end

if test "$window_count" -eq 1
    echo "Space $space_label is now empty. Destroying empty spaces..."
    yabai -m space "$space_label" --destroy
end


