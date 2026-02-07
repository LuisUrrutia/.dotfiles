#!/usr/bin/env fish

# Smart wake handler (yabai#259): only restart yabai if the display configuration
# changed during sleep. macOS often fires display_removed/display_added during wake
# (especially with 4K/5K monitors that take seconds to reconnect), and the
# on_display_removed/on_display_added handlers already handle space shuffling.
# A full restart is only needed when displays don't come back (e.g. undocked).
#
# Wait for displays to settle — external monitors (especially 4K/5K) can take
# 5-10 seconds to reconnect after wake.
sleep 5

set -l expected_displays 0
if test -f /tmp/yabai_expected_displays
    set expected_displays (cat /tmp/yabai_expected_displays)
end

set -l actual_displays (yabai -m query --displays | jq 'length')

if test "$actual_displays" != "$expected_displays"
    echo "[System Woke] Display count changed ($expected_displays -> $actual_displays), restarting yabai"
    yabai --restart-service
else
    echo "[System Woke] Display count unchanged ($actual_displays), skipping restart"
end
