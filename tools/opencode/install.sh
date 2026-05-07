#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

OPENCODE_SKILLS=(
  "https://github.com/zed-industries/zed humanizer"
  "https://github.com/anthropics/skills skill-creator"
  "https://github.com/vercel-labs/agent-skills vercel-composition-patterns"
  "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill ui-ux-pro-max"
  "mattpocock/skills diagnose"
  "mattpocock/skills grill-with-docs"
  "mattpocock/skills improve-codebase-architecture"
  "mattpocock/skills prototype"
  "mattpocock/skills tdd"
  "mattpocock/skills to-issues"
  "mattpocock/skills to-prd"
  "mattpocock/skills triage"
  "mattpocock/skills write-a-skill"
  "mattpocock/skills zoom-out"
  "vercel-labs/agent-browser"
  "LuisUrrutia/skills"
)

install_oh_my_opencode() {
  local -a omo_command
  if command -v bunx >/dev/null 2>&1; then
    omo_command=(bunx oh-my-openagent)
  elif command -v npx >/dev/null 2>&1; then
    omo_command=(npx oh-my-openagent)
  else
    echo "Warning: bunx or npx not found, skipping Oh My OpenAgent" >&2
    return
  fi

  "${omo_command[@]}" install --no-tui --skip-auth --claude=no --gemini=no --copilot=no
}

install_opencode_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    echo "Warning: npx not found, skipping OpenCode skills" >&2
    return
  fi

  local skill_source skill_name
  for skill in "${OPENCODE_SKILLS[@]}"; do
    skill_source="${skill% *}"
    skill_name="${skill##* }"

    if [[ -d "$OPENCODE_CONFIG_DIR/skills/$skill_name" ]]; then
      echo "OpenCode skill $skill_name already installed"
      continue
    fi

    npx skills@latest add "$skill_source" --skill "$skill_name" -g -y
  done
}

# Install OpenCode via curl because brew one is throttling it to 10 releases
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/install | bash
fi

export PATH="$HOME/.opencode/bin:$PATH"

stow_config opencode
install_oh_my_opencode
install_opencode_skills
