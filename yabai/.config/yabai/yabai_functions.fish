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

# Apply yabai window rules to assign apps to specific spaces
# Usage: apply_window_rules_for_space <space_name> <layout> <apps...>
function apply_window_rules_for_space
    set space_name $argv[1]
    set layout $argv[2]
    set apps $argv[3..-1]

    # Set layout if specified and not "bsp" (default)
    if test "$layout" != bsp
        echo "Setting $space_name layout to $layout"
        yabai -m space $space_name --layout $layout
    end

    # Add rules for each app
    for app in $apps
        echo "Mapping $app → $space_name"
        # Wrap app pattern in quotes to handle regex properly
        yabai -m rule --add app="$app" space=$space_name
    end
end

# Register window_created signals to dynamically create spaces when apps open
# Usage: register_window_created_signals_for_space <space_name> <layout> <apps...>
function register_window_created_signals_for_space
    set space_name $argv[1]
    set layout $argv[2]
    set apps $argv[3..-1]
    set events_dir "$HOME/.config/yabai/events"

    # Build the action command based on layout
    if test "$layout" = bsp
        set action "fish $events_dir/create_space.fish $space_name"
    else
        set action "fish $events_dir/create_space.fish $space_name $layout"
    end

    # Register signal for each app
    for app in $apps
        # Wrap app pattern in quotes to handle regex properly
        yabai -m signal --add event=window_created app="$app" action="$action"
    end
end

# Apply rules for non-managed apps
# Usage: apply_unmanaged_rules <apps...>
function apply_unmanaged_rules
    for app in $argv
        echo "Setting $app as unmanaged"
        yabai -m rule --add app="$app" manage=off
    end
end

# Apply rules for sticky apps (always on top, on all spaces)
# Usage: apply_sticky_rules <apps...>
function apply_sticky_rules
    for app in $argv
        echo "Setting $app as sticky"
        yabai -m rule --add app="$app" manage=off sticky=on sub-layer=above
    end
end

# Apply title-based rules
# Usage: apply_title_rule <app> <title_pattern> <manage> <sticky> <sub_layer>
function apply_title_rule
    set app $argv[1]
    set title $argv[2]
    set manage $argv[3]
    set sticky $argv[4]
    set sublayer $argv[5]

    yabai -m rule --add app="$app" title="$title" manage=$manage sticky=$sticky sub-layer=$sublayer
end
