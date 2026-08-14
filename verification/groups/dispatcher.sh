#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
/bin/bash tools/bin/tests/dotfiles.sh
/bin/bash tools/ai/tests/install.sh
/bin/bash verification/tests/run.sh
/bin/bash config/tests/lifecycle.sh
/bin/bash config/tests/resolve.sh
