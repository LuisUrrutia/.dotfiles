#!/usr/bin/env sh

# Get all spaces with no windows (excluding the first space)
empty_spaces=$(yabai -m query --spaces | jq "[.[] | select(.windows == [] and .index > 1) | .index] | sort | reverse")

# Destroy empty spaces
for space_index in $(echo "$empty_spaces" | jq -r ".[]"); do
  echo "Destroying empty space: $space_index"
  yabai -m space "$space_index" --destroy 2>/dev/null || true
done
