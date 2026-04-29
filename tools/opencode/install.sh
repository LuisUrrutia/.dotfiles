#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

install_oh_my_opencode() {
  if [[ -f "$OPENCODE_CONFIG_DIR/oh-my-openagent.json" || -f "$OPENCODE_CONFIG_DIR/oh-my-openagent.jsonc" ]]; then
    echo "Oh My OpenAgent already configured"
    return
  fi

  local -a omo_command
  if command -v bunx >/dev/null 2>&1; then
    omo_command=(bunx oh-my-opencode)
  elif command -v npx >/dev/null 2>&1; then
    omo_command=(npx oh-my-opencode)
  else
    echo "Warning: bunx or npx not found, skipping Oh My OpenAgent" >&2
    return
  fi

  "${omo_command[@]}" install --no-tui --skip-auth
}

# Install OpenCode via curl because brew one is throttling it to 10 releases
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/install | bash
fi

export PATH="$HOME/.opencode/bin:$PATH"

stow_config opencode
install_oh_my_opencode
