#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

install_oh_my_openagent() {
  if ! command -v bunx >/dev/null 2>&1; then
    echo "Warning: bunx not found, skipping Oh My OpenAgent" >&2
    return
  fi

  bunx oh-my-openagent install \
    --no-tui \
    --skip-auth \
    --claude=no \
    --openai=yes \
    --gemini=no \
    --copilot=no \
    --opencode-zen=no \
    --zai-coding-plan=no \
    --opencode-go=no \
    --kimi-for-coding=no \
    --vercel-ai-gateway=no
}

# Install OpenCode via curl because brew one is throttling it to 10 releases
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/install | bash
fi

export PATH="$HOME/.opencode/bin:$PATH"

stow_config opencode
install_oh_my_openagent
