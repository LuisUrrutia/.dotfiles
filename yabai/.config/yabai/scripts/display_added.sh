#!/usr/bin/env sh

# Get the number of displays
display_count=$(yabai -m query --displays | jq length)

if [ "$display_count" -eq 2 ]; then
  echo "Second display detected, moving spaces..."
  # Move specific spaces to the second display (display 2)
  # Adjust these space names/numbers according to your preference
  yabai -m space "other" --display 2
  yabai -m space "notes" --display 2
  yabai -m space "social" --display 2
  yabai -m space "work" --display 2
  echo "Spaces moved to second display"
fi
