#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" == Darwin ]]; then
  fisher="$(mise bootstrap packages where brew:fisher)/share/fish/vendor_functions.d/fisher.fish"
else
  fisher="$HOME/.local/share/fisher/functions/fisher.fish"
fi
manifest="$HOME/.config/fish/fish_plugins"
if [[ ! -e "$manifest" ]]; then
  install -m 600 "$HOME/.config/mise/conf.d/fish/fish_plugins" "$manifest"
fi
# Fish expands argv after Bash passes the command unchanged.
# shellcheck disable=SC2016
fish --command 'source "$argv[1]"; and fisher update' "$fisher" </dev/null
