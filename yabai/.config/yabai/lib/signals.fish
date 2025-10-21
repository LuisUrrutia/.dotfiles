#!/usr/bin/env fish
# Signals management functions

# Register window_created signals to dynamically create spaces when apps open
# Usage: register_signal_to_create_space_on_app_open <space_name> <layout> <preferred_display> <apps...>
function register_signal_to_create_space_on_app_open
    set space_name $argv[1]
    set layout $argv[2]
    set preferred_display $argv[3]
    set apps $argv[4..-1]

    set events_dir "$HOME/.config/yabai/events"
    set action "fish $events_dir/on_window_created.fish $space_name $layout $preferred_display"

    # Register signal for each app
    for app in $apps
        yabai -m signal --add event=window_created app="$app" action="$action"
    end
end