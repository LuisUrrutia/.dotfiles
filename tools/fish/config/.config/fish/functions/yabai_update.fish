function yabai_update
    echo "Updating yabai permissions..."
    set -l yabai_path (which yabai)
    set -l yabai_hash (shasum -a 256 $yabai_path | cut -d " " -f 1)
    set -l yabai_user (whoami)
    echo "$yabai_user ALL=(root) NOPASSWD: sha256:$yabai_hash $yabai_path --load-sa" | sudo tee /private/etc/sudoers.d/yabai
end
