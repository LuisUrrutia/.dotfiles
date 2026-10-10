#!/usr/bin/env bash
set -euo pipefail

scratch="$(mktemp -d)"
socket="mise-setup-$$"
trap 'tmux -L "$socket" kill-server >/dev/null 2>&1 || true; rm -rf "$scratch"' EXIT
config_path="$HOME/.tmux.conf"
HOME="$scratch" tmux -L "$socket" -f /dev/null start-server \; source-file -n "$config_path"
export DOTFILES_REAL_GIT
DOTFILES_REAL_GIT="$(command -v git)"
export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes'
export PATH="$HOME/.config/mise/conf.d/tmux/git-bin:$PATH"
for attempt in 1 2 3; do
  if tpack install; then exit 0; fi
  [[ "$attempt" == 3 ]] || sleep 5
done
echo 'TPack installation failed after three attempts.' >&2
exit 1
