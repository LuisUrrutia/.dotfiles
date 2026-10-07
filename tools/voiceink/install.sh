#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

if ! "$bin_path" which codex >/dev/null 2>&1; then
  echo "Warning: codex is not installed by mise, skipping" >&2
  exit 0
fi

voiceink_dir="$HOME/.local/share/voiceink-codex"
sources=(
  "$HOME/.codex/auth.json"
  "$HOME/.agents/skills/comment-style"
  "$HOME/.agents/skills/communicate-clearly"
)
targets=(
  "$voiceink_dir/auth.json"
  "$voiceink_dir/skills/comment-style"
  "$voiceink_dir/skills/communicate-clearly"
)

for directory in "$voiceink_dir" "$voiceink_dir/skills"; do
  if [[ -L "$directory" || ( -e "$directory" && ! -d "$directory" ) ]]; then
    printf 'Error: refusing unowned VoiceInk directory: %s\n' "$directory" >&2
    exit 1
  fi
done

for index in "${!sources[@]}"; do
  target="${targets[$index]}"
  if [[ -L "$target" && "$(readlink "$target")" == "${sources[$index]}" ]]; then
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    printf 'Error: refusing unowned VoiceInk destination: %s\n' "$target" >&2
    exit 1
  fi
done

umask 077
mkdir -p "$voiceink_dir" "$voiceink_dir/skills"
stow_config voiceink

for index in "${!sources[@]}"; do
  [[ -L "${targets[$index]}" ]] || ln -s "${sources[$index]}" "${targets[$index]}"
done

if [[ ! -f "$voiceink_dir/auth.json" ]]; then
  echo "Warning: Codex authentication is unavailable; run codex login before using VoiceInk" >&2
fi
for skill_name in comment-style communicate-clearly; do
  if [[ ! -f "$voiceink_dir/skills/$skill_name/SKILL.md" ]]; then
    printf 'Warning: %s is unavailable; run dotfiles tool apply skills before using VoiceInk\n' \
      "$skill_name" >&2
  fi
done
