#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

# Stows only the rulebooks (rules/rule.json + rules/user-rules/). Runtime state
# (logs/, cache/, rules/rule.lock) is written by the tool to ~/.cc-safety-net.
# The cc-safety-net plugin itself is loaded via tools/opencode (opencode.json).
stow_config cc-safety-net
