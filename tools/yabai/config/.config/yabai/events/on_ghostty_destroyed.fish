#!/usr/bin/env fish

# Deferred refocus for Ghostty native tab destruction.
# When a native tab is absorbed, the transient window is destroyed and yabai
# loses focus (drifts to another display). Refocus the persistent Ghostty window.

set -l ghostty_id (yabai -m query --windows | jq -r '[.[] | select((.app | ascii_downcase) == "ghostty" and .["is-floating"] == false)] | .[0].id // empty')

echo "[Ghostty Destroyed] wid=$YABAI_WINDOW_ID persistent=$ghostty_id"

if test -z "$ghostty_id"
    echo "[Ghostty Destroyed] No Ghostty window found, skipping"
    exit 0
end

set -l focused_app (yabai -m query --windows | jq -r '[.[] | select(.["has-focus"])][0].app // "none"' | string lower)
echo "[Ghostty Destroyed] Current focus: $focused_app"

if test "$focused_app" != "ghostty"
    echo "[Ghostty Destroyed] Refocusing Ghostty window $ghostty_id"
    yabai -m window --focus $ghostty_id 2>/dev/null; or true
else
    echo "[Ghostty Destroyed] Ghostty already focused"
end
