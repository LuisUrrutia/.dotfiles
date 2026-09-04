#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

stow_config node

require_brew_bin mise

# Node itself is installed by tools/mise (declared in mise's config.toml).
eval "$("$bin_path" activate bash)"

# Package cooldown (unit: days), matching pnpm's minimumReleaseAge and yarn's
# npmMinimalAgeGate (10080 min). Written into ~/.npmrc, which stays untracked
# because npm also keeps the registry auth token there.
npm config set min-release-age 7 --location=user

# bun comes from mise, so no Homebrew vendor completion exists; generate it
# the same way tools/python does for uv.
fish_config_dir="$HOME/.config/fish"
fish_completions_dir="$fish_config_dir/completions"

if [[ -L "$fish_config_dir" ]]; then
  echo "Warning: $fish_config_dir is a symlink; run tools/fish/install.sh before generating bun Fish completions" >&2
elif command -v bun >/dev/null 2>&1; then
  mkdir -p "$fish_completions_dir"
  SHELL=fish bun completions >"$fish_completions_dir/bun.fish"
fi
