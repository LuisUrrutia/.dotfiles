#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

stow_config skills

require_brew_bin mise

GLOBAL_SKILLS_AGENTS=(
  "opencode"
  "claude-code"
)

GLOBAL_SKILL_GROUPS=(
  "https://github.com/anthropics/skills|skill-creator"
  "https://github.com/vercel-labs/agent-skills|vercel-composition-patterns vercel-react-best-practices vercel-react-native-skills vercel-react-view-transitions web-design-guidelines writing-guidelines"
  "git@github.com:mattpocock/skills.git|grill-with-docs triage improve-codebase-architecture setup-matt-pocock-skills to-spec to-tickets implement wayfinder prototype diagnosing-bugs research tdd domain-modeling codebase-design code-review resolving-merge-conflicts wizard grill-me handoff teach to-questionnaire wait-what grilling writing-for-agents"
  "https://github.com/ast-grep/agent-skill.git|ast-grep"
  "LuisUrrutia/skills|commit pr daily-meeting-update github-actions humanize"
  "https://github.com/stablyai/orca|orca-cli orchestration computer-use orca-linear orca-emulator"
)

install_global_skills() {
  if ! "$bin_path" which skills >/dev/null 2>&1; then
    echo "Warning: skills is not installed by mise, skipping" >&2
    return 0
  fi

  local agent_flag skill_group skill_source skill_names skill_name
  local -a agent_args skill_args

  for agent_flag in "${GLOBAL_SKILLS_AGENTS[@]}"; do
    agent_args+=(--agent "$agent_flag")
  done

  for skill_group in "${GLOBAL_SKILL_GROUPS[@]}"; do
    skill_source="${skill_group%%|*}"
    skill_names="${skill_group#*|}"
    skill_args=()

    for skill_name in $skill_names; do
      skill_args+=(--skill "$skill_name")
    done

    "$bin_path" exec -- skills add "$skill_source" "${skill_args[@]}" "${agent_args[@]}" -g -y
  done
}

install_playwright_skills() {
  if ! "$bin_path" which playwright-cli >/dev/null 2>&1; then
    echo "Warning: playwright-cli is not installed by mise, skipping" >&2
    return 0
  fi

  "$bin_path" exec -- playwright-cli install --skills --global
  "$bin_path" exec -- playwright-cli install --skills=agents --global
}

install_global_skills
install_playwright_skills
