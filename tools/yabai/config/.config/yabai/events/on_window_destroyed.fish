#!/usr/bin/env fish

# Source required lib functions
set LIB_DIR "$HOME/.config/yabai/lib"
source "$LIB_DIR/spaces.fish"

set REMOVED_WINDOW_ID $YABAI_WINDOW_ID

# Get the space info using tab delimiter to handle labels with spaces
set space_info (yabai -m query --spaces | jq -r ".[] | select(.windows | index($REMOVED_WINDOW_ID)) | \"\(.label)\t\(.index)\"")

if test -z "$space_label"
    destroy_empty_spaces
    exit 0
end

set parts (string split \t $space_info)
set space_label $parts[1]
set space_index $parts[2]

# Use windows query as source of truth - the space's .windows array may be stale
set actual_window_count (yabai -m query --windows | jq "[.[] | select(.space == $space_index and .role != \"\")] | length")

if test "$actual_window_count" -le 1
    echo "Space $space_label is now empty. Destroying empty spaces..."
    if test -n "$space_label"
        yabai -m space "$space_label" --destroy
    else
        yabai -m space "$space_index" --destroy
    end
end
