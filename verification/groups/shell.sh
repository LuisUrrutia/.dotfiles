#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"

scripts=()
for script in \
  dotfiles install.sh private-install.sh cleanup.sh machines/*.sh .githooks/* \
  cli/*.sh \
  bootstrap/*.sh \
  brewfiles/*.sh brewfiles/tests/*.sh config/*.sh config/tests/*.sh \
  maintenance/*.sh maintenance/tests/*.sh \
  tools/lib.sh tools/*/install.sh tools/*/common.sh \
  tools/*/migrate-*.sh tools/*/config/.local/bin/* tools/*/tests/*.sh \
  tools/macos/prefs-diff.sh verification/run.sh verification/groups/*.sh \
  verification/tests/*.sh; do
  [[ -f "$script" ]] && scripts+=("$script")
done

for script in "${scripts[@]}"; do
  /bin/bash -n "$script"
done

shellcheck "${scripts[@]}"

for test_script in tools/*/tests/*.sh; do
  [[ "$test_script" == tools/hammerspoon/* ]] && continue
  [[ "$test_script" == tools/fish/* ]] && continue
  [[ "$test_script" == tools/ai/tests/install.sh ]] && continue
  [[ "$test_script" == tools/bin/tests/dotfiles.sh ]] && continue
  /bin/bash "$test_script"
done

for test_script in maintenance/tests/*.sh; do
  [[ -f "$test_script" ]] || continue
  /bin/bash "$test_script"
done
