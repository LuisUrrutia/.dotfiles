#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fish
require_brew_opt fisher

migrate_managed_folded_fish_config() {
  local source="$DOTFILES/tools/fish/config/.config/fish"
  local target="$HOME/.config/fish"
  local target_parent

  target_parent="$(dirname "$target")"

  if [[ ! -L "$target" ]]; then
    return 0
  fi

  local link_target
  local resolved_source
  local resolved_target

  link_target="$(readlink "$target")"
  resolved_source="$(cd "$source" && pwd -P)"

  if [[ "$link_target" = /* ]]; then
    resolved_target="$link_target"
  else
    resolved_target="$target_parent/$link_target"
  fi

  resolved_target="$(cd "$(dirname "$resolved_target")" && pwd -P)/$(basename "$resolved_target")"

  if [[ "$resolved_target" != "$resolved_source" ]]; then
    echo "Error: refusing to replace non-managed fish config symlink: $target -> $link_target" >&2
    echo "Expected symlink target: $source" >&2
    return 1
  fi

  rm "$target"
  mkdir -p "$target"

  if [[ -f "$source/fish_variables" && ! -e "$target/fish_variables" ]]; then
    cp -p "$source/fish_variables" "$target/fish_variables"
  fi
}

resolve_path_for_compare() {
  local path="$1"
  local parent

  parent="$(dirname "$path")"
  printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$(basename "$path")"
}

migrate_repo_owned_fish_file() {
  local relative_path="$1"
  local source="$DOTFILES/tools/fish/config/.config/fish/$relative_path"
  local target="$HOME/.config/fish/$relative_path"
  local backup=""

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return 0
  fi

  if [[ ! -f "$source" ]]; then
    echo "Error: missing repo-owned fish source: $source" >&2
    return 1
  fi

  if [[ -L "$target" ]]; then
    local link_target
    local resolved_source
    local resolved_target

    link_target="$(readlink "$target")"
    resolved_source="$(resolve_path_for_compare "$source")"

    if [[ "$link_target" = /* ]]; then
      resolved_target="$link_target"
    else
      resolved_target="$(dirname "$target")/$link_target"
    fi

    resolved_target="$(resolve_path_for_compare "$resolved_target")"

    if [[ "$resolved_target" == "$resolved_source" ]]; then
      return 0
    fi

    echo "Error: refusing to replace non-managed fish symlink: $target -> $link_target" >&2
    echo "Expected symlink target: $source" >&2
    return 1
  fi

  if [[ -d "$target" ]]; then
    echo "Error: refusing to replace fish directory with repo-owned file: $target" >&2
    return 1
  fi

  if cmp -s "$source" "$target"; then
    rm "$target"
    return 0
  fi

  backup="$target.local-backup.$(date +%Y%m%d%H%M%S).$$"
  mv "$target" "$backup"
  echo "Backed up local fish file before Stow ownership: $target -> $backup"
}

migrate_repo_owned_zoxide_files() {
  migrate_repo_owned_fish_file conf.d/zoxide.fish
  migrate_repo_owned_fish_file functions/zoxide.fish
  migrate_repo_owned_fish_file completions/zoxide.fish
}

migrate_managed_folded_fish_config
migrate_repo_owned_zoxide_files
stow_config fish

# Add fish to shells if not already present
grep -qxF "$bin_path" /etc/shells || printf '%s\n' "$bin_path" | sudo_askpass tee -a /etc/shells >/dev/null

# Set fish as default shell
if [[ "$SHELL" != "$bin_path" ]]; then
  chsh -s "$bin_path"
fi

# Install fish plugins
fish_plugins_path="$HOME/.config/fish/fish_plugins"
if [[ ! -f "$fish_plugins_path" ]]; then
  echo "Error: missing fish_plugins manifest: $fish_plugins_path" >&2
  exit 1
fi
"$bin_path" --command "source \"$opt_path/share/fish/vendor_functions.d/fisher.fish\"; and fisher update"
