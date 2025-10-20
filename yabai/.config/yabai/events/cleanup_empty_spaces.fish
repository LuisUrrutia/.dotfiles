#!/usr/bin/env fish

# Get all spaces with no windows (excluding the first space)
set empty_spaces (yabai -m query --spaces | jq "[.[] | select(.windows == [] and .index > 1) | .index] | sort | reverse")

# Destroy empty spaces
for space_index in (echo $empty_spaces | jq -r ".[]")
    echo "Destroying empty space: $space_index"
    yabai -m space "$space_index" --destroy 2>/dev/null; or true
end
