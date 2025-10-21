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