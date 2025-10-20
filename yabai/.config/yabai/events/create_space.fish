#!/usr/bin/env fish

# Usage: create_space.fish <space_label> [layout] [window_id]
# Example: create_space.fish code stack 12345

set SPACE_LABEL $argv[1]
set LAYOUT $argv[2]
set WINDOW_ID $YABAI_WINDOW_ID

if test -z "$SPACE_LABEL"
    echo "Error: Space label is required"
    exit 1
end

# Check if space already exists
set space_exists false
if yabai -m query --spaces | jq -e ".[] | select(.label == \"$SPACE_LABEL\")" >/dev/null 2>&1
    set space_exists true
end

if test "$space_exists" = false
    echo "Creating $SPACE_LABEL space..."
    yabai -m space --create
    yabai -m space last --label "$SPACE_LABEL"

    # Apply layout if specified
    if test -n "$LAYOUT"
        echo "Applying layout: $LAYOUT"
        yabai -m space "$SPACE_LABEL" --layout "$LAYOUT"
    end
end

# Move the window to the space if window ID is provided
if test -n "$WINDOW_ID"
    echo "Moving window $WINDOW_ID to space $SPACE_LABEL"
    yabai -m window "$WINDOW_ID" --space "$SPACE_LABEL"
    echo "Focusing space $SPACE_LABEL"
    yabai -m space --focus "$SPACE_LABEL"
end
