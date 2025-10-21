#!/usr/bin/env fish
# Window management functions

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

