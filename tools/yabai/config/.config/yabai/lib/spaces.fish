#!/usr/bin/env fish
# Space management functions

# Get the number of available displays
function get_display_count
    yabai -m query --displays | jq 'length'
end

# Check if a display with the given ID exists
# Usage: check_display_exists <display_id>
# Returns: 0 if exists, 1 if not
function check_display_exists
    set -l display_id $argv[1]
    set -l display_count (get_display_count)
    test $display_id -le $display_count
end

# Check if a space with the given label exists
# Usage: check_space_exists <space_label>
# Returns: 0 if exists, 1 if not
function check_space_exists
    set -l space_label $argv[1]
    yabai -m query --spaces | jq -e ".[] | select(.label == \"$space_label\")" >/dev/null 2>&1
end

# Move space to preferred display if it exists
# Usage: move_space_to_display <space_label> <preferred_display>
function move_space_to_display
    set -l space_label $argv[1]
    set -l preferred_display $argv[2]

    if test -z "$preferred_display"
        return 0
    end

    if check_display_exists $preferred_display
        echo "Moving space $space_label to display $preferred_display"
        yabai -m space "$space_label" --display $preferred_display 2>/dev/null; or true
    end
end

# Create a space if it doesn't exist and set layout
# Usage: ensure_space_exists <space_label> [layout]
# Returns: 0 if space already existed, 1 on error, 2 if space was created
function ensure_space_exists
    set -l space_label $argv[1]
    set -l layout $argv[2]

    if test -z "$space_label"
        echo "Error: Space label is required" >&2
        return 1
    end

    if not check_space_exists $space_label
        echo "[Ensure Space Exists] Space $space_label doesnt exist... creating"

        # Get all space indices before creating
        set -l spaces_before (yabai -m query --spaces | jq -r '.[].index')

        yabai -m space --create

        # Get all space indices after creating, find the new one
        set -l spaces_after (yabai -m query --spaces | jq -r '.[].index')
        set -l new_space_index
        for space in $spaces_after
            if not contains $space $spaces_before
                set new_space_index $space
                break
            end
        end
        if test -z "$new_space_index"
            echo "Error: Failed to create new space" >&2
            return 1
        end
        echo "[Ensure Space Exists] new space index is $new_space_index"

        yabai -m space "$new_space_index" --label "$space_label"
        yabai -m space "$space_label" --layout "$layout"
        return 2
    else
        echo "[Ensure Space Exists] Space $space_label already exists"
        return 0
    end
end


function destroy_empty_spaces
    echo "Destroying empty spaces..."

    set were_removed false
    set displays (yabai -m query --displays | jq '.[] | .index')

    # Use windows query as source of truth for which spaces have windows
    # The spaces query .windows array can be out of sync
    set all_windows_json (yabai -m query --windows)
    set occupied_spaces (get_occupied_spaces "$all_windows_json")

    # Query all spaces once to avoid repeated yabai queries in the loop
    set all_spaces_json (yabai -m query --spaces)

    for display in $displays
        set spaces_on_display_count (echo $all_spaces_json | jq "[.[] | select(.display == $display)] | length")

        # Get unlabeled spaces that have no windows according to windows query
        set unlabeled_spaces_to_delete (echo $all_spaces_json | jq -r "[.[] | select(.display == $display and .label == \"\")] | .[].index")

        for space_index in $unlabeled_spaces_to_delete
            # macOS requires at least 1 space per display — never destroy the last one
            if test $spaces_on_display_count -le 1
                echo "[Destroy Empty Spaces] Keeping last space on display $display"
                break
            end
            if not contains $space_index $occupied_spaces
                echo "[Destroy Empty Spaces] Destroying empty unlabeled space: $space_index on display $display"
                yabai -m space "$space_index" --destroy
                set spaces_on_display_count (math $spaces_on_display_count - 1)
            end
        end

        # Get labeled spaces that have no windows according to windows query
        set spaces_to_delete
        set all_spaces_on_display (echo $all_spaces_json | jq -r "[.[] | select(.display == $display and .label != \"\")] | .[] | \"\(.index):\(.label)\"")

        for space_info in $all_spaces_on_display
            set space_index (string split ':' $space_info)[1]
            set space_label (string split ':' $space_info)[2]

            if not contains $space_index $occupied_spaces
                set -a spaces_to_delete $space_label
            end
        end
        set spaces_to_delete_count (count $spaces_to_delete)

        echo "[Destroy Empty Spaces] Spaces in display $display: $spaces_on_display_count. Empty: $spaces_to_delete ($spaces_to_delete_count)"

        for space_label in $spaces_to_delete
            # macOS requires at least 1 space per display — never destroy the last one
            if test $spaces_on_display_count -le 1
                echo "[Destroy Empty Spaces] Keeping last space ($space_label) on display $display"
                break
            end
            echo "[Destroy Empty Spaces] Destroying empty space: $space_label on display $display"
            yabai -m space "$space_label" --destroy
            set spaces_on_display_count (math $spaces_on_display_count - 1)
            set were_removed true
        end
    end

    if test "$were_removed" = true
        echo "[Destroy Empty Spaces] Applying yabai rules after space destruction..."
        sleep 1
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
