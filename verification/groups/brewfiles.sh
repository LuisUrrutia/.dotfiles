#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
/bin/bash brewfiles/check.sh
