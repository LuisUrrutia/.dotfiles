#!/usr/bin/env bash
set -euo pipefail

export GH_PROMPT_DISABLED=1 GIT_TERMINAL_PROMPT=0
gh extension list | awk '{print $3}' | grep -Fxq github/gh-stack || gh extension install https://github.com/github/gh-stack.git
