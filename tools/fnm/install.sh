#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin fnm
fnm="$bin_path"

"$fnm" install --lts
"$fnm" default lts-latest

sudo ln -sf "$HOME/.local/share/fnm/aliases/default/bin/node" /usr/local/bin/node
sudo ln -sf "$HOME/.local/share/fnm/aliases/default/bin/npm" /usr/local/bin/npm
sudo ln -sf "$HOME/.local/share/fnm/aliases/default/bin/npx" /usr/local/bin/npx
sudo ln -sf "$HOME/.local/share/fnm/aliases/default/bin/corepack" /usr/local/bin/corepack
