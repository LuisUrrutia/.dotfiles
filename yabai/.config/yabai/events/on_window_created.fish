#!/usr/bin/env fish

# Source required lib functions
set lib_dir "$HOME/.config/yabai/lib"

source "$lib_dir/spaces.fish"
source "$lib_dir/windows.fish"

set SPACE_LABEL $argv[1]
set LAYOUT $argv[2]
set PREFERRED_DISPLAY $argv[3]
set WINDOW_ID $YABAI_WINDOW_ID

# Validate required parameter
if test -z "$SPACE_LABEL"
    echo "Error: Space label is required" >&2
    exit 1
end

set code (ensure_space_exists "$SPACE_LABEL" "$LAYOUT")
if test $status -eq 1
    echo "Error: Failed to ensure space exists" >&2
    exit 1
end

# If space was created, move it to preferred display
if test "$code" = "created"
    move_space_to_display "$SPACE_LABEL" "$PREFERRED_DISPLAY"
end

move_windows_id_to_space "$WINDOW_ID" "$SPACE_LABEL"

# Focus the newly created window
yabai -m window --focus "$WINDOW_ID"
