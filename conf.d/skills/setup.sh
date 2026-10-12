#!/usr/bin/env bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0
skills add https://github.com/anthropics/skills.git --skill frontend-design --agent claude-code codex -g -y
skills add https://github.com/vercel-labs/agent-skills.git --skill vercel-react-best-practices vercel-composition-patterns --agent claude-code codex -g -y
skills add https://github.com/kitlangton/2password.git --skill 2password --agent claude-code codex -g -y
skills add https://github.com/tester-army/e2e.git --skill e2e --agent claude-code codex -g -y
playwright-cli install --skills --global
playwright-cli install --skills=agents --global
