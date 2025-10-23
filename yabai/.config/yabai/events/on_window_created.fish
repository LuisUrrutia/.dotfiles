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

echo "[On Window Created] Ensure space $SPACE_LABEL exists"

ensure_space_exists "$SPACE_LABEL" "$LAYOUT"
set ensure_space_exists_code $status
if test $ensure_space_exists_code -eq 1
    echo "Error: Failed to ensure space exists" >&2
    exit 1
end

# If space was created, move it to preferred display
if test $ensure_space_exists_code -eq 201
    echo "[On Window Created] Space $SPACE_LABEL created, moving to display $PREFERRED_DISPLAY"
    move_space_to_display "$SPACE_LABEL" "$PREFERRED_DISPLAY"
end

move_windows_id_to_space "$WINDOW_ID" "$SPACE_LABEL"

# Focus the newly created window
yabai -m window --focus "$WINDOW_ID"
