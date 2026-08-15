#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"
/bin/bash brewfiles/check.sh
/bin/bash brewfiles/tests/cleanup.sh
ruby brewfiles/tests/platform_compatibility.rb
