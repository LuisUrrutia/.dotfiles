#!/usr/bin/env fish

# Deferred refocus for Ghostty native tab creation.
# When a native tab is created, yabai reports it as a new window and may shift
# focus to another display. This window IS the Ghostty tab group — focus it directly.

yabai -m window --focus $YABAI_WINDOW_ID 2>/dev/null; or true
