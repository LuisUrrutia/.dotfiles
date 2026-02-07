#!/usr/bin/env fish
# Window management functions

# Apps that use native macOS tabs and may report an empty role to yabai (yabai#68).
# These must be explicitly included when counting "real" windows, otherwise closing
# a tab can falsely make a space appear empty and trigger space destruction.
# Brave Browser is included because dragging tabs to new windows triggers rapid
# window_created/window_destroyed events that cause layout chaos (yabai#2599, #2717).
set -g NATIVE_TAB_APPS ghostty "brave browser"

# jq filter fragment: selects windows that are "real" — either they have a role
# (standard yabai-managed windows) or they are a known native-tab app.
# Usage: jq "[.[] | select($JQ_REAL_WINDOW_FILTER)] | length"
set -g JQ_REAL_WINDOW_FILTER '.role != "" or (.app | ascii_downcase) as $a | ["ghostty", "brave browser"] | any(. == $a)'

# Count real windows on a given space using pre-fetched windows JSON.
# Accounts for apps using native macOS tabs that may report empty roles (yabai#68).
# Usage: count_real_windows_on_space <windows_json> <space_index>
function count_real_windows_on_space
    set -l windows_json $argv[1]
    set -l space_index $argv[2]
    echo $windows_json | jq "[.[] | select(.space == $space_index and ($JQ_REAL_WINDOW_FILTER))] | length"
end

# Get occupied space indices from pre-fetched windows JSON, accounting for native tabs.
# Usage: get_occupied_spaces <windows_json>
# Returns: list of unique space indices that have real windows
function get_occupied_spaces
    set -l windows_json $argv[1]
    echo $windows_json | jq -r "[.[] | select($JQ_REAL_WINDOW_FILTER)] | .[].space" | sort -u
end

# Resize two apps on the same space with specific ratios
# The left app is positioned on the left. Ratios <= 0 are ignored.
function resize_app_pair
    set -l space_label $argv[1]
    set -l left_app $argv[2]
    set -l left_ratio $argv[3]
    set -l right_app $argv[4]
    set -l right_ratio $argv[5]

    # Single query to get space index
    set -l space_index (yabai -m query --spaces | jq -r ".[] | select(.label == \"$space_label\") | .index")
    test -z "$space_index"; and return 0

    # Single query to get both windows with id and x position
    set -l windows_data (yabai -m query --windows | jq -r --argjson space "$space_index" \
        "[.[] | select(.space == \$space)] |
         { left: (.[] | select(.app == \"$left_app\") | {id, x: .frame.x}),
           right: (.[] | select(.app == \"$right_app\") | {id, x: .frame.x}) } |
         \"\\(.left.id // \"\") \\(.left.x // 0 | floor) \\(.right.id // \"\") \\(.right.x // 0 | floor)\"")

    set -l parts (string split ' ' $windows_data)
    set -l left_window $parts[1]
    set -l left_x $parts[2]
    set -l right_window $parts[3]
    set -l right_x $parts[4]

    # Early return if either window is missing
    test -z "$left_window" -o -z "$right_window"; and return 0

    echo "[Resize] Both $left_app ($left_window) and $right_app ($right_window) found on $space_label"

    # Swap if windows are in wrong positions
    if test $left_x -gt $right_x
        echo "[Resize] Swapping window positions"
        yabai -m window $left_window --swap $right_window 2>/dev/null; or true
    end

    # Apply ratios (only if > 0)
    if set -l ratio_int (math "floor($left_ratio * 100)" 2>/dev/null); and test $ratio_int -gt 0
        yabai -m window $left_window --ratio abs:$left_ratio 2>/dev/null; or true
        echo "[Resize] $left_app at $left_ratio"
    end

    if set -l ratio_int (math "floor($right_ratio * 100)" 2>/dev/null); and test $ratio_int -gt 0
        yabai -m window $right_window --ratio abs:$right_ratio 2>/dev/null; or true
        echo "[Resize] $right_app at $right_ratio"
    end
end

# Resize BusyCal (35%) and Slack (65%) on work space
function resize_busycal_with_slack
    resize_app_pair work BusyCal 0.35 Slack 0
end

# Exit native fullscreen mode for all windows
function exit_native_fullscreen_windows
    echo "Exiting native fullscreen windows..."
    for win_id in (yabai -m query --windows | jq '.[] | select(.["is-native-fullscreen"] == true) | .id')
        echo "Exiting native fullscreen for window: $win_id"
        yabai -m window "$win_id" --toggle native-fullscreen
    end
end

# Move window IDs to a specific space
# Usage: move_windows_id_to_space <window_id> <space_name>
function move_windows_id_to_space
    set windows_id $argv[1]
    set space_name $argv[2]

    echo "Moving windows ID $windows_id to $space_name space..."
    yabai -m window "$windows_id" --space "$space_name" 2>/dev/null; or true
end

# =============================================================================
# LAYOUT SAVE/RESTORE (yabai#259)
# =============================================================================
# When displays disconnect/reconnect, yabai retiles all windows with default
# ratios, losing custom splits (e.g. BusyCal 35%/Slack 65%). These functions
# snapshot window positions before the retile and restore order + ratios after.

set -g YABAI_LAYOUT_FILE /tmp/yabai_layout.json

# Save current window layout to JSON. Call BEFORE spaces are moved/retiled.
# Captures tiled window positions per labeled space, sorted left-to-right.
function save_layout
    echo "[Layout] Saving window layout..."
    set -l spaces_json (yabai -m query --spaces)

    yabai -m query --windows | jq --argjson spaces "$spaces_json" '
        ($spaces | map({key: (.index | tostring), value: .label}) | from_entries) as $labels |
        [.[] | select(
            .["is-visible"] and (.["is-floating"] | not) and (.["is-minimized"] | not) and
            $labels[.space | tostring] and ($labels[.space | tostring] != "")
        ) | {
            id, app,
            space_label: $labels[.space | tostring],
            x: .frame.x, y: .frame.y, w: .frame.w, h: .frame.h
        }] | group_by(.space_label) | map({
            space_label: .[0].space_label,
            windows: sort_by(.x, .y)
        })
    ' > $YABAI_LAYOUT_FILE

    echo "[Layout] Saved to $YABAI_LAYOUT_FILE"
end

# Restore window order and BSP ratios from a saved snapshot.
# Call AFTER spaces have been moved to their final displays and retiled.
# Handles 2-window spaces (swap + ratio restore). 3+ windows log a warning.
function restore_layout
    if not test -f $YABAI_LAYOUT_FILE
        echo "[Layout] No snapshot found, skipping restore"
        return 0
    end

    echo "[Layout] Restoring window layout..."

    set -l snapshot (cat $YABAI_LAYOUT_FILE)
    set -l num_spaces (echo $snapshot | jq 'length')

    if test "$num_spaces" = "0" -o "$num_spaces" = "null"
        echo "[Layout] Empty snapshot, skipping"
        rm -f $YABAI_LAYOUT_FILE
        return 0
    end

    set -l spaces_json (yabai -m query --spaces)
    set -l windows_json (yabai -m query --windows)

    # Process each space in the snapshot
    for i in (seq 0 (math $num_spaces - 1))
        set -l space_label (echo $snapshot | jq -r ".[$i].space_label")
        set -l space_index (echo $spaces_json | jq -r ".[] | select(.label == \"$space_label\") | .index")

        if test -z "$space_index"
            echo "[Layout] Space $space_label not found, skipping"
            continue
        end

        # Saved window IDs in original left-to-right order
        set -l saved_ids (echo $snapshot | jq -r ".[$i].windows[].id")
        set -l saved_count (count $saved_ids)

        # Current windows on this space, sorted by x position
        set -l current_ids (echo $windows_json | jq -r "[.[] | select(.space == $space_index and (.\"is-floating\" | not) and .\"is-visible\")] | sort_by(.frame.x, .frame.y) | .[].id")
        set -l current_count (count $current_ids)

        if test $saved_count -le 1 -o $current_count -le 1
            continue
        end

        if test $saved_count -ne $current_count
            echo "[Layout] Window count changed on $space_label ($saved_count -> $current_count), skipping"
            continue
        end

        if test $saved_count -eq 2
            # 2-window space: restore order and ratio
            if test "$saved_ids[1]" != "$current_ids[1]"
                echo "[Layout] Restoring window order on $space_label"
                yabai -m window $saved_ids[1] --swap $saved_ids[2] 2>/dev/null; or true
            end

            # Compute and restore the horizontal split ratio from saved frame widths
            set -l ratio (echo $snapshot | jq -r ".[$i].windows | .[0].w / (.[0].w + .[1].w) | . * 100 | round / 100")
            if test -n "$ratio" -a "$ratio" != "null" -a "$ratio" != "0.5"
                echo "[Layout] Restoring ratio $ratio on $space_label (window $saved_ids[1])"
                yabai -m window $saved_ids[1] --ratio abs:$ratio 2>/dev/null; or true
            end
        else
            echo "[Layout] Space $space_label has $saved_count windows, order/ratio restore not yet supported"
        end
    end

    echo "[Layout] Restore complete"
    rm -f $YABAI_LAYOUT_FILE
end
