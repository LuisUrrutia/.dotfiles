#!/usr/bin/env bash
set -euo pipefail

skills add git@github.com:anthropics/skills.git --skill frontend-design --agent claude-code -g -y
skills add git@github.com:vercel-labs/agent-skills.git --skill vercel-react-best-practices vercel-composition-patterns --agent claude-code -g -y
skills add git@github.com:addyosmani/agent-skills.git --skill performance-optimization --agent claude-code -g -y
skills add git@github.com:kitlangton/2password.git --skill 2password --agent claude-code -g -y
skills add git@github.com:tester-army/e2e.git --skill e2e --agent claude-code -g -y
skills add git@github.com:LuisUrrutia/skills.git --skill comment-style communicate-clearly --agent claude-code -g -y
playwright-cli install --skills --global
playwright-cli install --skills=agents --global
