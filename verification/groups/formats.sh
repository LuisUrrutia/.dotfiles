#!/usr/bin/env bash

set -euo pipefail

cd "$DOTFILES"

python3 verification/check-configs.py

while IFS= read -r -d '' config_file; do
  taplo check "$config_file"
done < <(find tools -path '*/config/*' -type f -name '*.toml' -print0)

yaml_files=()
while IFS= read -r -d '' config_file; do
  yaml_files+=("$config_file")
done < <(find tools -path '*/config/*' -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
if ((${#yaml_files[@]} > 0)); then
  ruby -e 'require "yaml"; ARGV.each { |path| YAML.safe_load(File.read(path), [], [], true, path) }' \
    "${yaml_files[@]}"
fi

while IFS= read -r -d '' script; do
  esbuild "$script" --format=esm --log-level=error --outfile=/dev/null
done < <(find tools -path '*/config/*' -type f \
  \( -name '*.js' -o -name '*.cjs' -o -name '*.mjs' \) -print0)

check-jsonschema --schemafile verification/schemas/claude-settings.schema.json \
  tools/claude/config/.claude/settings.json
check-jsonschema --schemafile verification/schemas/opencode.schema.json \
  tools/opencode/config/.config/opencode/opencode.json
check-jsonschema --schemafile verification/schemas/cc-index.schema.json \
  tools/cc-safety-net/config/.cc-safety-net/rules/rule.json
check-jsonschema --schemafile verification/schemas/cc-rulebook.schema.json \
  tools/cc-safety-net/config/.cc-safety-net/rules/user-rules/rulebook.json

editorconfig-checker -exclude \
  '(^|/)(archived/|tools/git/tests/migrate-config\.sh$|tools/raycast/backups/|tools/thaw/Thaw\.plist$)'
