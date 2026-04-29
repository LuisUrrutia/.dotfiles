function yabai_update -d "Update yabai sudoers permissions"
    command -q yabai; or begin; echo "Error: yabai not found."; return 1; end
    command -q shasum; or begin; echo "Error: shasum not found."; return 1; end

    echo "Updating yabai permissions..."

    set -l yabai_path (command -s yabai)
    set -l yabai_hash (shasum -a 256 "$yabai_path" | string split --fields 1 ' ')
    set -l yabai_user (whoami)

    if test -z "$yabai_hash"
        echo "Error: failed to compute yabai hash."
        return 1
    end

    echo "$yabai_user ALL=(root) NOPASSWD: sha256:$yabai_hash $yabai_path --load-sa" | sudo tee /private/etc/sudoers.d/yabai >/dev/null
end
