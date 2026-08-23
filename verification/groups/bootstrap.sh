#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"

/bin/bash verification/tests/bootstrap.sh
/bin/bash verification/tests/github-preflight.sh
/bin/bash install.sh --dry-run
/bin/bash install.sh --dry-run --core-only
/bin/bash install.sh --dry-run --all-profiles
/bin/bash install.sh --dry-run --profile web3,streaming,audio
/bin/bash install.sh --dry-run --profile blockchain,obs,focusrite
DOTFILES_HARDWARE_HASH_OVERRIDE=55930b1d4d8e /bin/bash install.sh --dry-run
