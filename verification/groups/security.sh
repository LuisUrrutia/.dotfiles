#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
gitleaks detect --source . --no-git --redact --no-banner
