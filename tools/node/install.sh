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
