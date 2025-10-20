#!/usr/bin/env fish

echo "Display removed, consolidating spaces to main display..."
# Move all spaces to display 1 (main display)
for space in (yabai -m query --spaces | jq -r ".[].label")
    yabai -m space "$space" --display 1 2>/dev/null; or true
end
echo "All spaces moved to main display"
