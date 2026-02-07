#!/usr/bin/env fish

# Auto-focus the first visible window when switching spaces.
# Guard: only focus if no window anywhere already has focus. This prevents
# stealing focus during internal events (e.g. native tab creation on display 2
# causing a spurious space_changed on display 1).
set -l focused_window (yabai -m query --windows | jq -r '[.[] | select(."has-focus")] | length')
if test "$focused_window" -gt 0
    exit 0
end

set window (yabai -m query --windows --space | jq -r '[.[]|select(."is-visible" and .layer != "unknown")][0].id')
if test -n "$window" -a "$window" != "null"
    yabai -m window --focus $window
end
