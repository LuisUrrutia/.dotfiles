#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"

while IFS= read -r -d '' script; do
  fish --no-execute "$script"
done < <(find tools/fish -type f -name '*.fish' -print0)

for test_script in tools/fish/tests/*.sh; do
  [[ -f "$test_script" ]] || continue
  /bin/bash "$test_script"
done
