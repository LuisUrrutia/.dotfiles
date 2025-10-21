#!/usr/bin/env fish
# Space management functions

# Get the number of available displays
function get_display_count
    yabai -m query --displays | jq 'length'
end

# Check if a display with the given ID exists
# Usage: check_display_exists <display_id>
function check_display_exists
    set display_id $argv[1]

    set display_count (get_display_count)
    if test $display_id -le $display_count
        echo true
    else
        echo false
    end
end

# Check if a space with the given label exists
# Usage: check_space_exists <space_label>
function check_space_exists
    set space_label $argv[1]

    if yabai -m query --spaces | jq -e ".[] | select(.label == \"$space_label\")" >/dev/null 2>&1
        echo true
    else
        echo false
    end
end

# Move space to preferred display if it exists
# Usage: move_space_to_display <space_label> <preferred_display>
function move_space_to_display
    set space_label $argv[1]
    set preferred_display $argv[2]

    if test -z "$preferred_display"
        return 0
    end

    # Check if the preferred display exists
    set display_exists (check_display_exists $preferred_display)
    if test "$display_exists" = true
        echo "Moving space $space_label to display $preferred_display"

        yabai -m space "$space_label" --display $preferred_display 2>/dev/null; or true
    end
end

# Create a space if it doesn't exist and set layout
# Usage: ensure_space_exists <space_label> [layout]
# Returns: "created" if space was created, "exists" if it already existed
function ensure_space_exists
    set space_label $argv[1]
    set layout $argv[2]

    if test -z "$space_label"
        echo "Error: Space label is required" >&2
        return 1
    end

    set space_exists (check_space_exists $space_label)

    if test "$space_exists" = false
        yabai -m space --create

        # Get the index of the space we just created
        # This is kinda a hack, because we look for the last unlabeled empty space
        set -l new_space_index (yabai -m query --spaces | jq '[.[] | select(.label == "" and (.windows | length == 0))] | last | .index')

        yabai -m space "$new_space_index" --label "$space_label"
        yabai -m space "$space_label" --layout "$layout"
        echo "created"
        return 0
    else
        echo "exists"
        return 0
    end
end

function destroy_empty_spaces
    echo "Destroying empty spaces..."

    set where_removed false
    set displays (yabai -m query --displays | jq '.[] | .index')
    for display in $displays
        set spaces_on_display (yabai -m query --spaces | jq "[.[] | select(.display == $display)] | length")
        set spaces_to_delete (yabai -m query --spaces | jq -r "[.[] | select(.display == $display and (.windows | length == 0))] | .[] | .label")

        echo "For $display we should delete spaces: $spaces_to_delete"

        set spaces_to_delete_count (count $spaces_to_delete)

        # If all spaces on this display are empty, keep one. MacOS requires at least one space per display.
        if test $spaces_to_delete_count -eq $spaces_on_display
            set spaces_to_delete $spaces_to_delete[1..-2]
        end

        for space_label in $spaces_to_delete
            echo "Destroying empty space: $space_label on display $display"
            yabai -m space "$space_label" --destroy

            set where_removed true
        end
    end

    if test "$where_removed" = true
        echo "Applying yabai rules after space destruction..."
        yabai -m rule --apply
    end
end

# Setup spaces with given labels
function setup_spaces_with_labels
    echo "Setting up spaces..."
    set desired (count $argv)
    set current (yabai -m query --spaces | jq 'length')

    while test $current -lt $desired
        set current (math "$current + 1")

        echo "Creating space $current"
        yabai -m space --create
    end

    set index 1
    for space in $argv
        echo "Labeling space $index as $space"
        yabai -m space $index --label "$space"

        set index (math "$index + 1")
    end
end

# Apply yabai window rules to assign apps to specific spaces
# Usage: configure_space_layout_and_rules <space_name> <layout> <apps...>
function configure_space_layout_and_rules
    set space_label $argv[1]
    set layout $argv[2]
    set apps $argv[3..-1]

    echo "Configuring space: $space_label"

    # Set layout if specified and not "bsp" (default)
    echo "Setting $space_label layout to $layout"
    yabai -m space $space_label --layout $layout

    # Add rules for each app
    for app in $apps
        echo "Mapping $app to space $space_label"
        yabai -m rule --add app="$app" space=$space_label
    end
end