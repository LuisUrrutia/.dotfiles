#!/usr/bin/env fish
# Yabai helper functions

function exit_native_fullscreen_windows
    echo "Exiting native fullscreen windows..."
    for win_id in (yabai -m query --windows | jq '.[] | select(.["is-native-fullscreen"] == true) | .id')
        echo "Exiting native fullscreen for window: $win_id"
        yabai -m window "$win_id" --toggle native-fullscreen
    end
end

function setup_spaces_with_labels
    echo "Setting up spaces..."
    set desired (count $argv)
    set current (yabai -m query --spaces | jq 'length')

    # First, create spaces until we have the desired count
    while test $current -lt $desired
        set idx (math $current + 1)
        echo "Creating space $idx"
        yabai -m space --create
        set current (math $current + 1)
    end

    # Then, label each space according to the provided names
    set idx 0
    for name in $argv
        set idx (math $idx + 1)
        echo "Labeling space $idx: $name"
        yabai -m space "$idx" --label "$name"
    end
end

function destroy_spaces_beyond_max
    set max $argv[1]
    echo "Destroying spaces beyond max: $max"
    for space_idx in (yabai -m query --spaces | jq '.[].index | select(. > '"$max"')')
        yabai -m space --destroy (math $max + 1)
    end
end
