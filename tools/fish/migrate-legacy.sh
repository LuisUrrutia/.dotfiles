#!/usr/bin/env bash

# Remove only broken links that still name one of the retired Fish-owned
# maintenance sources. The suffix check intentionally accepts an older clone
# location while refusing regular files, working links, and unrelated links.
migrate_retired_fish_links() {
  local relative_path=""
  local target=""
  local link_target=""

  for relative_path in \
    functions/upd.fish \
    conf.d/00_mise-activate.fish \
    conf.d/zz_atuin.fish \
    functions/backup-configs.fish \
    completions/upd.fish; do
    target="$HOME/.config/fish/$relative_path"
    [[ -L "$target" && ! -e "$target" ]] || continue

    link_target="$(readlink "$target")"
    case "$link_target" in
    */tools/fish/config/.config/fish/"$relative_path")
      rm "$target"
      printf 'Removed retired Fish symlink: %s\n' "$target"
      ;;
    esac
  done
}
