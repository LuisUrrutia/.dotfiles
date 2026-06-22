#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

GLOBAL_SKILLS_AGENTS=(
  "opencode"
  "claude-code"
)

GLOBAL_SKILL_GROUPS=(
  "https://github.com/anthropics/skills|skill-creator"
  "https://github.com/vercel-labs/agent-skills|vercel-react-best-practices vercel-composition-patterns vercel-react-view-transitions web-design-guidelines"
  "mattpocock/skills|grill-with-docs triage improve-codebase-architecture to-issues to-prd prototype diagnosing-bugs tdd domain-modeling codebase-design grill-me handoff teach writing-great-skills grilling setup-matt-pocock-skills"
  "https://github.com/ast-grep/agent-skill.git|ast-grep"
  "LuisUrrutia/skills|commit pr daily-meeting-update github-actions humanize"
)

install_global_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    echo "Warning: npx not found, skipping global skills" >&2
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

    npx --yes skills@latest add "$skill_source" "${skill_args[@]}" "${agent_args[@]}" -g -y
  done
}

install_global_skills
