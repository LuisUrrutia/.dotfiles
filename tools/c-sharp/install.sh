#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

eval "$("$bin_path" activate bash)"

"$bin_path" use dotnet@8
"$bin_path" use dotnet@10
