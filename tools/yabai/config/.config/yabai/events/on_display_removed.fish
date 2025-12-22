#!/usr/bin/env fish

echo "[Display Removed] Consolidating spaces to main display..."
# Move all spaces to display 1 (main display)
for space_label in (yabai -m query --spaces | jq -r ".[].label")
    yabai -m space "$space_label" --display 1
end
echo "[Display Removed] All spaces moved to main display"
