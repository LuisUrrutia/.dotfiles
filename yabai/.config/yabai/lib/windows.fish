#!/usr/bin/env fish
# Usage: resize_app_pair <space_label> <left_app> <left_ratio> <right_app> <right_ratio>
# Window management functions

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
