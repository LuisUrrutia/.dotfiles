#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

OPENCODE_SKILL_GROUPS=(
  "https://github.com/zed-industries/zed|humanizer"
  "https://github.com/anthropics/skills|skill-creator"
  "https://github.com/vercel-labs/agent-skills|vercel-composition-patterns"
  "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill|ui-ux-pro-max"
  "mattpocock/skills|diagnose grill-with-docs improve-codebase-architecture prototype tdd to-issues to-prd triage write-a-skill zoom-out setup-matt-pocock-skills handoff"
  "vercel-labs/agent-browser|agent-browser"
  "LuisUrrutia/skills|commit pr daily-meeting-update github-actions"
)

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

install_opencode_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    echo "Warning: npx not found, skipping OpenCode skills" >&2
    return
  fi

  local skill_group skill_source skill_names skill_name
  local -a skill_args

  for skill_group in "${OPENCODE_SKILL_GROUPS[@]}"; do
    skill_source="${skill_group%%|*}"
    skill_names="${skill_group#*|}"
    skill_args=()

    for skill_name in $skill_names; do
      if [[ -d "$OPENCODE_CONFIG_DIR/skills/$skill_name" ]]; then
        echo "OpenCode skill $skill_name already installed"
        continue
      fi

      skill_args+=(--skill "$skill_name")
    done

    if ((${#skill_args[@]} == 0)); then
      continue
    fi

    npx skills@latest add "$skill_source" "${skill_args[@]}" -g -y
  done
}

# Install OpenCode via curl because brew one is throttling it to 10 releases
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/install | bash
fi

export PATH="$HOME/.opencode/bin:$PATH"

stow_config opencode
install_oh_my_openagent
install_opencode_skills
