#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_brew_bin mise

if ! "$bin_path" which codex >/dev/null 2>&1; then
  echo "Warning: codex is not installed by mise, skipping" >&2
  exit 0
fi

settings_source="$DOTFILES/tools/codex/settings.toml"
config_dir="$HOME/.codex"
config_target="$config_dir/config.toml"

if [[ -L "$config_dir" ]]; then
  echo "Error: refusing unowned Codex config directory symlink: $config_dir" >&2
  exit 1
fi

mkdir -p "$config_dir"

if [[ ! -e "$config_target" && ! -L "$config_target" ]]; then
  /usr/bin/install -m 600 "$settings_source" "$config_target"
  echo "Created Codex config with managed settings: $config_target"
  exit 0
fi

if [[ -L "$config_target" ]]; then
  echo "Error: refusing unowned Codex config symlink: $config_target" >&2
  exit 1
fi

if [[ ! -f "$config_target" ]]; then
  echo "Error: refusing non-regular Codex config: $config_target" >&2
  exit 1
fi

temporary_config="$(mktemp "$config_target.tmp.XXXXXX")"

cleanup() {
  [[ ! -e "$temporary_config" ]] || rm "$temporary_config"
}
trap cleanup EXIT

/usr/bin/awk '
  function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
  }

  function fail(message) {
    print "Error: " message >"/dev/stderr"
    fatal = 1
    exit 1
  }

  function setting_path(table, key) {
    return table == "" ? key : table "." key
  }

  function validate_settings() {
    if (settings_validated) {
      return
    }
    if (desired_count != 6 ||
        desired["personality"] !~ /^"(none|friendly|pragmatic)"$/ ||
        desired["model_reasoning_effort"] !~ /^"(minimal|low|medium|high|xhigh)"$/ ||
        desired["plan_mode_reasoning_effort"] !~ /^"(none|minimal|low|medium|high|xhigh)"$/ ||
        desired["web_search"] !~ /^"(disabled|cached|indexed|live)"$/ ||
        desired["skills.max_context_tokens"] !~ /^[1-9][0-9]*$/ ||
        desired["skills.max_context_tokens"] + 0 > 10000 ||
        desired["features.memories"] !~ /^(true|false)$/) {
      fail("invalid managed Codex settings in " ARGV[1])
    }
    settings_validated = 1
  }

  function emit_top_level_settings(    position, path) {
    for (position = 1; position <= top_level_count; position++) {
      path = top_level_order[position]
      if (!wrote[path]) {
        print path " = " desired[path]
        wrote[path] = 1
        added_top_level = 1
      }
    }
    if (added_top_level) {
      print ""
      added_top_level = 0
    }
    emitted_top_level = 1
  }

  function emit_table_setting(table, key,    path) {
    path = setting_path(table, key)
    if (!wrote[path]) {
      print key " = " desired[path]
      wrote[path] = 1
    }
  }

  function finish_table(table) {
    if (table == "skills") {
      emit_table_setting("skills", "max_context_tokens")
    } else if (table == "features") {
      emit_table_setting("features", "memories")
    }
  }

  function append_missing_table(table, key,    path) {
    path = setting_path(table, key)
    if (!saw_table[table]) {
      if (output_lines > 0) {
        print ""
      }
      print "[" table "]"
      print key " = " desired[path]
      wrote[path] = 1
      output_lines += 2
    }
  }

  BEGIN {
    allowed["personality"] = 1
    allowed["model_reasoning_effort"] = 1
    allowed["plan_mode_reasoning_effort"] = 1
    allowed["web_search"] = 1
    allowed["skills.max_context_tokens"] = 1
    allowed["features.memories"] = 1

    top_level_order[++top_level_count] = "personality"
    top_level_order[++top_level_count] = "model_reasoning_effort"
    top_level_order[++top_level_count] = "plan_mode_reasoning_effort"
    top_level_order[++top_level_count] = "web_search"
  }

  NR == FNR {
    line = $0
    sub(/[[:space:]]*#.*$/, "", line)
    line = trim(line)
    if (line == "") {
      next
    }

    if (line ~ /^\[[^][]+\]$/) {
      settings_table = line
      sub(/^\[/, "", settings_table)
      sub(/\]$/, "", settings_table)
      if (settings_table != "skills" && settings_table != "features") {
        fail("unsupported managed Codex settings table: " settings_table)
      }
      next
    }

    equals = index(line, "=")
    if (!equals) {
      fail("invalid managed Codex setting: " line)
    }
    key = trim(substr(line, 1, equals - 1))
    value = trim(substr(line, equals + 1))
    path = setting_path(settings_table, key)
    if (!allowed[path]) {
      fail("unsupported managed Codex setting: " path)
    }
    if (path in desired) {
      fail("duplicate managed Codex setting: " path)
    }
    desired[path] = value
    desired_count++
    next
  }

  FNR == 1 {
    validate_settings()
  }

  {
    line = $0
    comparable = line
    sub(/[[:space:]]*#.*$/, "", comparable)
    comparable = trim(comparable)

    if (comparable ~ /^\[.*\]$/) {
      finish_table(current_table)
      if (!emitted_top_level) {
        emit_top_level_settings()
      }

      current_table = "other"
      if (comparable == "[skills]" || comparable == "[features]") {
        current_table = comparable
        sub(/^\[/, "", current_table)
        sub(/\]$/, "", current_table)
        saw_table[current_table]++
        if (saw_table[current_table] > 1) {
          fail("refusing duplicate Codex table: " current_table)
        }
      }

      print line
      output_lines++
      next
    }

    equals = index(comparable, "=")
    if (equals) {
      key = trim(substr(comparable, 1, equals - 1))
      path = setting_path(current_table == "other" ? "" : current_table, key)

      if ((current_table == "" && allowed[path]) ||
          (current_table == "skills" && path == "skills.max_context_tokens") ||
          (current_table == "features" && path == "features.memories")) {
        seen[path]++
        if (seen[path] > 1) {
          fail("refusing duplicate Codex setting: " path)
        }
        print key " = " desired[path]
        wrote[path] = 1
        output_lines++
        next
      }
    }

    print line
    output_lines++
  }

  END {
    if (fatal) {
      exit 1
    }
    validate_settings()
    finish_table(current_table)
    if (!emitted_top_level) {
      emit_top_level_settings()
    }
    append_missing_table("skills", "max_context_tokens")
    append_missing_table("features", "memories")
  }
' "$settings_source" "$config_target" >"$temporary_config"

if cmp -s "$temporary_config" "$config_target"; then
  rm "$temporary_config"
  trap - EXIT
  echo "Codex settings already configured"
  exit 0
fi

backup="$config_target.local-backup.$(date +%Y%m%d%H%M%S).$$"
chmod "$(stat -f '%Lp' "$config_target")" "$temporary_config"
cp -p "$config_target" "$backup"
mv "$temporary_config" "$config_target"
trap - EXIT

echo "Configured managed Codex settings"
echo "Backed up Codex config: $backup"
