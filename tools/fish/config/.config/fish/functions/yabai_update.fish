function yabai_update -d "Update yabai sudoers permissions"
    command -q yabai; or begin
        echo "Error: yabai not found."
        return 1
    end
    command -q shasum; or begin
        echo "Error: shasum not found."
        return 1
    end
    command -q mktemp; or begin
        echo "Error: mktemp not found."
        return 1
    end
    command -q install; or begin
        echo "Error: install not found."
        return 1
    end

    echo "Updating yabai permissions..."

    set -l yabai_path (command -s yabai)
    set -l yabai_hash (shasum -a 256 "$yabai_path" | string split --fields 1 ' ')
    set -l yabai_user (whoami)

    if test -z "$yabai_hash"
        echo "Error: failed to compute yabai hash."
        return 1
    end

    set -l sudoers_file (mktemp)
    if test -z "$sudoers_file"
        echo "Error: failed to create temporary sudoers file."
        return 1
    end

    printf '%s ALL=(root) NOPASSWD: sha256:%s %s --load-sa\n' "$yabai_user" "$yabai_hash" "$yabai_path" >"$sudoers_file"
    sudo install -o root -g wheel -m 0440 "$sudoers_file" /private/etc/sudoers.d/yabai
    set -l install_status $status
    rm -f "$sudoers_file"
    return $install_status
end
