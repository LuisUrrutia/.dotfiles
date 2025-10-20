#!/usr/bin/env sh

# Usage: create_space.sh <space_label> [layout] [window_id]
# Example: create_space.sh code stack 12345

SPACE_LABEL="$1"
LAYOUT="$2"
WINDOW_ID="$YABAI_WINDOW_ID"

if [ -z "$SPACE_LABEL" ]; then
  echo "Error: Space label is required"
  exit 1
fi

# Check if space already exists
space_exists=$(yabai -m query --spaces | jq -e ".[] | select(.label == \"$SPACE_LABEL\")" > /dev/null && echo "true" || echo "false")

if [ "$space_exists" = "false" ]; then
  echo "Creating $SPACE_LABEL space..."
  yabai -m space --create
  yabai -m space last --label "$SPACE_LABEL"

  # Apply layout if specified
  if [ -n "$LAYOUT" ]; then
    echo "Applying layout: $LAYOUT"
    yabai -m space "$SPACE_LABEL" --layout "$LAYOUT"
  fi
fi

# Move the window to the space if window ID is provided
if [ -n "$WINDOW_ID" ]; then
  echo "Moving window $WINDOW_ID to space $SPACE_LABEL"
  yabai -m window "$WINDOW_ID" --space "$SPACE_LABEL"
  echo "Focusing space $SPACE_LABEL"
  yabai -m space --focus "$SPACE_LABEL"
fi
