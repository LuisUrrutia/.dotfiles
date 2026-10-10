#!/usr/bin/env bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0
skills add https://github.com/anthropics/skills.git --skill frontend-design --agent claude-code -g -y
skills add https://github.com/vercel-labs/agent-skills.git --skill vercel-react-best-practices vercel-composition-patterns --agent claude-code -g -y
skills add https://github.com/addyosmani/agent-skills.git --skill performance-optimization --agent claude-code -g -y
skills add https://github.com/kitlangton/2password.git --skill 2password --agent claude-code -g -y
skills add https://github.com/tester-army/e2e.git --skill e2e --agent claude-code -g -y
skills add https://github.com/LuisUrrutia/skills.git --skill comment-style communicate-clearly --agent claude-code -g -y
playwright-cli install --skills --global
playwright-cli install --skills=agents --global
