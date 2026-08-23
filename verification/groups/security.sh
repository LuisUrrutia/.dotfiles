#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
gitleaks detect --source . --no-git --redact --no-banner
/bin/bash verification/tests/pre-commit.sh
