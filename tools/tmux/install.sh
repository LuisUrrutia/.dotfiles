#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tmux
tmux_bin_path="$bin_path"
require_brew_bin git
git_bin_path="$bin_path"

tmux_min_major=3
tmux_min_minor=5
tmux_version="$("$tmux_bin_path" -V)"
tmux_version="${tmux_version#tmux }"
if [[ ! "$tmux_version" =~ ^([0-9]+)\.([0-9]+) ]]; then
  echo "Error: could not parse tmux version: $tmux_version" >&2
  exit 1
fi
tmux_major="${BASH_REMATCH[1]}"
tmux_minor="${BASH_REMATCH[2]}"
if (( tmux_major < tmux_min_major || (tmux_major == tmux_min_major && tmux_minor < tmux_min_minor) )); then
  echo "Error: tmux $tmux_min_major.$tmux_min_minor or newer is required; found $tmux_version" >&2
  exit 1
fi

tpm_dir="$HOME/.tmux/plugins/tpm"
tpm_ref="v3.1.0"
tpm_commit="c628645dfa7c4fc16acfb7a73c9d7a98697b472c"
if [[ ! -d "$tpm_dir" ]]; then
  mkdir -p "$(dirname "$tpm_dir")"
  "$git_bin_path" clone --branch "$tpm_ref" --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
fi

if [[ ! -x "$tpm_dir/bin/install_plugins" ]]; then
  echo "Error: TPM install_plugins is missing or not executable: $tpm_dir/bin/install_plugins" >&2
  exit 1
fi

tpm_current_commit="$("$git_bin_path" -C "$tpm_dir" rev-parse HEAD 2>/dev/null || true)"
if [[ "$tpm_current_commit" != "$tpm_commit" ]]; then
  echo "Error: TPM must be at $tpm_ref ($tpm_commit); found ${tpm_current_commit:-unknown}" >&2
  echo "Remove $tpm_dir and rerun this installer to recreate the pinned checkout." >&2
  exit 1
fi

stow_config tmux

tmux_config_path="$HOME/.tmux.conf"
tmux_socket="dotfiles-tmux-install-$$"
tmux_tmp_home="$(mktemp -d)"
cleanup_tmux_validation() {
  HOME="$tmux_tmp_home" "$tmux_bin_path" -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmux_tmp_home"
}
trap cleanup_tmux_validation EXIT

HOME="$tmux_tmp_home" "$tmux_bin_path" -L "$tmux_socket" -f /dev/null start-server \; source-file "$tmux_config_path"
echo "Validated tmux config with isolated server"

"$tpm_dir/bin/install_plugins"
