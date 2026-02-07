#!/usr/bin/env fish

# Source required lib functions
set lib_dir "$HOME/.config/yabai/lib"
source "$lib_dir/spaces.fish"
source "$lib_dir/windows.fish"

set REMOVED_WINDOW_ID $YABAI_WINDOW_ID

# Try fast path: find the space via spaces query .windows array
set -l all_spaces_json (yabai -m query --spaces)
set space_info (echo $all_spaces_json | jq -r ".[] | select(.windows | index($REMOVED_WINDOW_ID)) | \"\(.label)\t\(.index)\t\(.[\"has-focus\"])\"")

# Fallback: the window may still exist in the windows query even if spaces .windows is stale
if test -z "$space_info"
    set -l space_index (yabai -m query --windows | jq -r ".[] | select(.id == $REMOVED_WINDOW_ID) | .space")
    if test -n "$space_index"
        set space_info (echo $all_spaces_json | jq -r ".[] | select(.index == $space_index) | \"\(.label)\t\(.index)\t\(.[\"has-focus\"])\"")
    end
end

# Neither method found the space — run full scan as last resort
if test -z "$space_info"
    destroy_empty_spaces
    exit 0
end

set parts (string split \t $space_info)
set space_label $parts[1]
set space_index $parts[2]
set space_focused $parts[3]

# Use windows query as source of truth — the space's .windows array may be stale.
# Uses the shared real-window filter from windows.fish which accounts for native tab
# apps (yabai#68) that may report empty roles.
# Check <= 1 because the destroyed window may or may not still appear in the query
# depending on timing of yabai's internal cleanup.
set all_windows_json (yabai -m query --windows)
set actual_window_count (count_real_windows_on_space "$all_windows_json" $space_index)

if test "$actual_window_count" -le 1
    # macOS requires at least 1 space per display — never destroy the last one.
    set -l display_id (echo $all_spaces_json | jq -r ".[] | select(.index == $space_index) | .display")
    set -l spaces_on_display (echo $all_spaces_json | jq "[.[] | select(.display == $display_id)] | length")

    if test "$spaces_on_display" -le 1
        echo "[Window Destroyed] Space $space_index is the last space on display $display_id, keeping it"
    else
        # Guard against racing handlers: when closing the last tab in a native-tab app,
        # yabai fires window_destroyed for both the tab and the container window.
        # Two handlers race — the first destroys the space, the second must not fail.
        if test -n "$space_label"
            if check_space_exists "$space_label"
                echo "Space $space_label is now empty. Destroying..."
                yabai -m space "$space_label" --destroy
            end
        else
            echo "Unlabeled space $space_index is now empty. Destroying..."
            yabai -m space "$space_index" --destroy 2>/dev/null; or true
        end
    end
else if test "$space_focused" = "true"
    # Space still has windows and is the focused space — refocus a remaining window.
    # When native tab apps (Ghostty, Brave) absorb a transient window into a tab group,
    # the transient window was briefly focused by yabai. Its destruction leaves no focused
    # window, causing yabai to drift focus to another display (e.g. Zed on display 1).
    # Explicitly focusing a remaining window on this space prevents the drift.
    set -l remaining_window (echo $all_windows_json | jq -r \
        "[.[] | select(.space == $space_index and .id != $REMOVED_WINDOW_ID and ($JQ_REAL_WINDOW_FILTER))] | .[0].id // empty")
    if test -n "$remaining_window"
        echo "[Window Destroyed] Refocusing window $remaining_window on space $space_index"
        yabai -m window --focus $remaining_window 2>/dev/null; or true
    end
end
