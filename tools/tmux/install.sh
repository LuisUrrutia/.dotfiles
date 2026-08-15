#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tmux
tmux_bin_path="$bin_path"
require_brew_bin git
require_brew_bin mise
mise_bin_path="$bin_path"

if ! tpack_bin_path="$("$mise_bin_path" which tpack 2>/dev/null)" ||
  [[ ! -x "$tpack_bin_path" ]]; then
  echo "Error: mise-owned TPack is unavailable; run dotfiles tool apply mise" >&2
  exit 1
fi
tpack_bin_dir="$(dirname "$tpack_bin_path")"

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

stow_config tmux

tmux_config_path="$HOME/.tmux.conf"
tmux_socket="dotfiles-tmux-install-$$"
tmux_tmp_home="$(mktemp -d)"
cleanup_tmux_validation() {
  HOME="$tmux_tmp_home" "$tmux_bin_path" -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmux_tmp_home"
}
trap cleanup_tmux_validation EXIT

HOME="$tmux_tmp_home" PATH="$tpack_bin_dir:$PATH" \
  "$tmux_bin_path" -L "$tmux_socket" -f /dev/null start-server \; source-file -n "$tmux_config_path"
echo "Validated tmux config syntax with isolated server"

PATH="$tpack_bin_dir:$PATH" "$tpack_bin_path" install
