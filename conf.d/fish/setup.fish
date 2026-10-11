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

# Fisher can rewrite the manifest and return success after a partial download failure.
set requested (string match --regex -- '^[^\s]+$' <"$snapshot" | string replace -- \~ ~)
fisher update </dev/null
set result $status
set installed (fisher list)
for plugin in $requested
    if test -e "$plugin"
        set plugin (realpath "$plugin")
    else
        set plugin (string lower -- "$plugin")
    end
    if not contains -- "$plugin" $installed
        echo "Fish plugin was not installed: $plugin" >&2
        set result 1
    end
end
exit $result
