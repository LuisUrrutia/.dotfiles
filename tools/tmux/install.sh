#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin tmux
tmux_bin_path="$bin_path"
require_brew_bin git
git_bin_path="$bin_path"
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

normalize_legacy_tpack_origins() {
  local plugin_dir
  local origin_url
  local clean_origin_url
  local plugin_name

  for plugin_dir in "$HOME"/.tmux/plugins/*; do
    [[ -d "$plugin_dir/.git" && ! -L "$plugin_dir" ]] || continue
    if ! origin_url="$(
      "$git_bin_path" -c transfer.credentialsInUrl=allow \
        -C "$plugin_dir" config --get remote.origin.url 2>/dev/null
    )"; then
      continue
    fi

    case "$origin_url" in
    https://*@github.com/*)
      clean_origin_url="https://github.com/${origin_url#*@github.com/}"
      ;;
    *)
      continue
      ;;
    esac

    case "$clean_origin_url" in
    https://github.com/tmux-plugins/tmux-resurrect | \
      https://github.com/tmux-plugins/tmux-resurrect.git | \
      https://github.com/catppuccin/tmux | \
      https://github.com/catppuccin/tmux.git | \
      https://github.com/sainnhe/tmux-fzf | \
      https://github.com/sainnhe/tmux-fzf.git | \
      https://github.com/tmux-plugins/tmux-continuum | \
      https://github.com/tmux-plugins/tmux-continuum.git)
      ;;
    *)
      continue
      ;;
    esac

    if ! "$git_bin_path" -c transfer.credentialsInUrl=allow \
      -C "$plugin_dir" remote set-url origin "$clean_origin_url"; then
      echo "Error: could not normalize legacy TPack origin: ${plugin_dir##*/}" >&2
      return 1
    fi
    plugin_name="${plugin_dir##*/}"
    echo "Normalized legacy TPack origin without embedded credentials: $plugin_name"
  done
}

normalize_legacy_tpack_origins

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

install_tpack_plugins() {
  local max_attempts="${DOTFILES_TPACK_MAX_ATTEMPTS:-5}"
  local attempt=1
  local retry_delay=5
  local delay

  while [[ "$attempt" -le "$max_attempts" ]]; do
    if PATH="$tpack_bin_dir:$PATH" "$tpack_bin_path" install; then
      return 0
    fi

    if [[ "$attempt" -lt "$max_attempts" ]]; then
      delay="${DOTFILES_TPACK_RETRY_DELAY_SECONDS:-$retry_delay}"
      echo "Warning: TPack plugin installation failed (attempt $attempt/$max_attempts); retrying in ${delay}s." >&2
      sleep "$delay"
    fi

    attempt=$((attempt + 1))
    retry_delay=$((retry_delay * 2))
  done

  echo "Error: TPack could not install all plugins after $max_attempts attempts." >&2
  echo "Check GitHub connectivity, then rerun: dotfiles tool apply tmux" >&2
  return 1
}

install_tpack_plugins
