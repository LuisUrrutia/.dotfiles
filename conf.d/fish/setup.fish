#!/usr/bin/env fish

if not type -q fisher
    echo 'Fisher is unavailable; apply the Fish module first.' >&2
    exit 1
end

set manifest "$HOME/.config/fish/fish_plugins"
if test -L "$manifest"
    echo "Refusing redirected plugin manifest: $manifest" >&2
    exit 1
end
if not test -e "$manifest"
    install -m 600 (status dirname)/fish_plugins "$manifest"; or exit 1
end

set snapshot (mktemp "$manifest.XXXXXX"); or exit 1
cp -p "$manifest" "$snapshot"; or exit 1
function restore_manifest --on-event fish_exit --inherit-variable snapshot --inherit-variable manifest
    command mv -f -- "$snapshot" "$manifest"
end

set installed (fisher list)
set requested
for plugin in (string match --regex -- '^[^\s]+$' <"$snapshot" | string replace -- \~ ~)
    if test -e "$plugin"
        set plugin (realpath "$plugin")
    else
        set plugin (string lower -- "$plugin")
    end
    contains -- "$plugin" $requested; or set -a requested "$plugin"
end

# Fisher appends the whole manifest on its first install and hides mixed download failures.
printf '' >"$manifest"; or exit 1
set result 0
for plugin in $requested
    set action install
    contains -- "$plugin" $installed; and set action update
    if not fisher $action "$plugin" </dev/null
        echo "Fish plugin $action failed: $plugin" >&2
        set result 1
    end
    if not contains -- "$plugin" (fisher list)
        echo "Fish plugin was not installed: $plugin" >&2
        set result 1
    end
end
for plugin in $installed
    contains -- "$plugin" $requested; or fisher remove "$plugin" </dev/null; or set result 1
end
exit $result
