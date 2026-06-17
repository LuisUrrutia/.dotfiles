#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

GLOBAL_SKILLS_DIR="$HOME/.agents/skills"
GLOBAL_SKILLS_REQUIRED_AGENT="Claude Code"

OPENCODE_SKILL_GROUPS=(
  "https://github.com/anthropics/skills|skill-creator"
  "https://github.com/vercel-labs/agent-skills|vercel-composition-patterns"
  "mattpocock/skills|diagnose grill-with-docs improve-codebase-architecture prototype tdd to-issues to-prd triage write-a-skill zoom-out setup-matt-pocock-skills handoff"
  "vercel-labs/agent-browser|agent-browser"
  "LuisUrrutia/skills|commit pr daily-meeting-update github-actions humanize"
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

list_global_skills() {
  local skills_list

  skills_list="$(npx --yes skills@latest ls -g | sed $'s/\x1B\[[0-9;]*m//g')"
  printf '%s\n' "${skills_list//\~\/.agents\/skills/$GLOBAL_SKILLS_DIR}"
}

global_skill_is_ready() {
  local skills_list="$1"
  local skill_name="$2"

  awk \
    -v skill_name="$skill_name" \
    -v skills_dir="$GLOBAL_SKILLS_DIR" \
    -v required_agent="$GLOBAL_SKILLS_REQUIRED_AGENT" '
      $1 == skill_name &&
      $2 == skills_dir "/" skill_name &&
      index($0, "Agents:") &&
      index($0, required_agent) {
        found = 1
      }
      END {
        exit found ? 0 : 1
      }
    ' <<<"$skills_list"
}

install_opencode_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    echo "Warning: npx not found, skipping OpenCode skills" >&2
    return
  fi

  local skill_group skill_source skill_names skill_name global_skills
  local -a skill_args

  if ! global_skills="$(list_global_skills)"; then
    echo "Warning: could not list global skills, reinstalling requested OpenCode skills" >&2
    global_skills=""
  fi

  for skill_group in "${OPENCODE_SKILL_GROUPS[@]}"; do
    skill_source="${skill_group%%|*}"
    skill_names="${skill_group#*|}"
    skill_args=()

    for skill_name in $skill_names; do
      if global_skill_is_ready "$global_skills" "$skill_name"; then
        echo "OpenCode skill $skill_name already installed for $GLOBAL_SKILLS_REQUIRED_AGENT"
        continue
      fi

      skill_args+=(--skill "$skill_name")
    done

    if ((${#skill_args[@]} == 0)); then
      continue
    fi

    npx --yes skills@latest add "$skill_source" "${skill_args[@]}" --agent opencode -g -y
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
