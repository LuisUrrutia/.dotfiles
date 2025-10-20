#!/usr/bin/env sh

echo "Display removed, consolidating spaces to main display..."
# Move all spaces to display 1 (main display)
for space in $(yabai -m query --spaces | jq -r ".[].label"); do
  yabai -m space "$space" --display 1 2>/dev/null || true
done
echo "All spaces moved to main display"
