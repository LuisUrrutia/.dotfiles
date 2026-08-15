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
tpack_git_wrapper_dir="$DOTFILES/tools/tmux/tpack-bin"
if [[ ! -x "$tpack_git_wrapper_dir/git" ]]; then
  echo "Error: TPack Git logger is unavailable: $tpack_git_wrapper_dir/git" >&2
  exit 1
fi

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

append_tpack_git_logs() {
  local attempt_log_dir="$1"
  local tpack_log_path="$2"
  local git_log

  for git_log in "$attempt_log_dir"/git-command-*.log; do
    [[ -f "$git_log" ]] || continue
    /bin/cat "$git_log" >>"$tpack_log_path"
  done
}

install_tpack_plugins() {
  local max_attempts="${DOTFILES_TPACK_MAX_ATTEMPTS:-5}"
  local attempt=1
  local retry_delay=5
  local delay
  local tpack_log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/logs"
  local tpack_log_path
  local tpack_version
  local git_version
  local tpack_git_log_root="$tmux_tmp_home/tpack-git"
  local attempt_git_log_dir

  tpack_log_path="$tpack_log_dir/tmux-tpack-install-$(date -u '+%Y%m%dT%H%M%SZ')-$$.log"
  mkdir -p "$tpack_log_dir"
  chmod 700 "$tpack_log_dir"
  : >"$tpack_log_path"
  chmod 600 "$tpack_log_path"

  tpack_version="$(PATH="$tpack_bin_dir:$PATH" "$tpack_bin_path" version 2>&1 || printf 'unavailable')"
  git_version="$("$git_bin_path" --version 2>&1 || printf 'unavailable')"
  {
    printf 'started_at_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'tpack_version=%s\n' "$tpack_version"
    printf 'git_version=%s\n' "$git_version"
    printf 'tmux_version=tmux %s\n' "$tmux_version"
    printf 'max_attempts=%s\n' "$max_attempts"
  } >>"$tpack_log_path"
  echo "TPack install log: $tpack_log_path"

  while [[ "$attempt" -le "$max_attempts" ]]; do
    attempt_git_log_dir="$tpack_git_log_root/attempt-$attempt"
    mkdir -p "$attempt_git_log_dir"
    printf 'attempt=%s/%s status=started at_utc=%s\n' \
      "$attempt" "$max_attempts" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>"$tpack_log_path"
    if DOTFILES_TPACK_REAL_GIT="$git_bin_path" \
      DOTFILES_TPACK_GIT_LOG_DIR="$attempt_git_log_dir" \
      PATH="$tpack_git_wrapper_dir:$tpack_bin_dir:$PATH" \
      "$tpack_bin_path" install 2>&1 |
      /usr/bin/tee -a "$tpack_log_path"; then
      append_tpack_git_logs "$attempt_git_log_dir" "$tpack_log_path"
      printf 'attempt=%s/%s status=succeeded at_utc=%s\n' \
        "$attempt" "$max_attempts" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>"$tpack_log_path"
      return 0
    fi
    append_tpack_git_logs "$attempt_git_log_dir" "$tpack_log_path"
    printf 'attempt=%s/%s status=failed at_utc=%s\n' \
      "$attempt" "$max_attempts" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>"$tpack_log_path"

    if [[ "$attempt" -lt "$max_attempts" ]]; then
      delay="${DOTFILES_TPACK_RETRY_DELAY_SECONDS:-$retry_delay}"
      echo "Warning: TPack plugin installation failed (attempt $attempt/$max_attempts); retrying in ${delay}s." >&2
      sleep "$delay"
    fi

    attempt=$((attempt + 1))
    retry_delay=$((retry_delay * 2))
  done

  echo "Error: TPack could not install all plugins after $max_attempts attempts." >&2
  echo "Detailed TPack log: $tpack_log_path" >&2
  echo "Check GitHub connectivity, then rerun: dotfiles tool apply tmux" >&2
  return 1
}

install_tpack_plugins
