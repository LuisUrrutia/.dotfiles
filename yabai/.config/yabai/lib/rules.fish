#!/usr/bin/env fish
# Yabai helper functions

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
