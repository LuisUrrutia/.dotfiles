#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'dotfiles config: %s\n' "$*" >&2
  exit 1
}

valid_tool_name() {
  local tool="$1"
  [[ -n "$tool" && "$tool" != .* && "$tool" != */* && "$tool" != *..* ]]
}

valid_home_path() {
  local path="$1"
  [[ -n "$path" && "$path" != /* && "$path" != '~'* && "$path" != ./* && "$path" != */../* && "$path" != ../* && "$path" != */.. && "$path" != *//* && "$path" != */./* && "$path" != */. ]]
}

entry_is_ignored() {
  local tool="$1"
  local path="$2"
  local ignore_file="$DOTFILES/tools/$tool/config/.stow-local-ignore"
  local pattern=""

  [[ -f "$ignore_file" ]] || return 1
  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    [[ -n "$pattern" && "$pattern" != '#'* ]] || continue
    if [[ "/$path" =~ $pattern ]]; then
      return 0
    fi
  done <"$ignore_file"
  return 1
}

list_entries() {
  local tool="$1"
  local prefix="tools/$tool/config/"
  local tracked=""
  local path=""

  valid_tool_name "$tool" || return 1
  [[ -d "$DOTFILES/tools/$tool/config" ]] || return 1

  while IFS= read -r tracked; do
    [[ "$tracked" == "$prefix"* ]] || continue
    [[ -f "$DOTFILES/$tracked" && ! -L "$DOTFILES/$tracked" ]] || continue
    path="${tracked#"$prefix"}"
    [[ -n "$path" && "$path" != .stow-local-ignore ]] || continue
    entry_is_ignored "$tool" "$path" && continue
    printf '%s\n' "$path"
  done < <(git -C "$DOTFILES" ls-files -- "tools/$tool/config")
}

tool_has_entries() {
  local first=""
  first="$(list_entries "$1" | sed -n '1p')"
  [[ -n "$first" ]]
}

require_tool() {
  local tool="$1"
  valid_tool_name "$tool" || fail "invalid tool: $tool"
  tool_has_entries "$tool" || fail "tool has no eligible Stowed Config: $tool"
}

require_entry() {
  local tool="$1"
  local requested="$2"
  local path=""

  valid_home_path "$requested" || fail "invalid home-relative path: $requested"
  while IFS= read -r path; do
    [[ "$path" == "$requested" ]] && return 0
  done < <(list_entries "$tool")
  fail "path is not an eligible Managed Config Entry: $requested"
}

canonical_existing_path() {
  local path="$1"
  local directory=""
  local basename_value=""

  directory="$(dirname "$path")"
  basename_value="$(basename "$path")"
  directory="$(cd "$directory" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$directory" "$basename_value"
}

entry_state() {
  local tool="$1"
  local path="$2"
  local source="$DOTFILES/tools/$tool/config/$path"
  local live="$HOME/$path"
  local target=""
  local candidate=""
  local source_canonical=""
  local candidate_canonical=""
  local compare_status=0

  if [[ -L "$live" ]]; then
    target="$(readlink "$live")"
    if [[ "$target" == /* ]]; then
      candidate="$target"
    else
      candidate="$(dirname "$live")/$target"
    fi
    if [[ -e "$live" ]]; then
      source_canonical="$(canonical_existing_path "$source")" || fail "cannot resolve tracked source: $path"
      candidate_canonical="$(canonical_existing_path "$candidate")" || {
        printf 'conflict\n'
        return
      }
      if [[ "$candidate_canonical" == "$source_canonical" ]]; then
        printf 'linked\n'
        return
      fi
    fi
    printf 'conflict\n'
    return
  fi

  if [[ ! -e "$live" ]]; then
    printf 'missing\n'
    return
  fi

  if [[ -f "$live" ]]; then
    if cmp -s "$source" "$live"; then
      compare_status=0
    else
      compare_status=$?
    fi

    if [[ "$compare_status" -gt 1 ]]; then
      fail "cannot compare tracked and live files: $path"
    fi

    if [[ "$compare_status" -eq 0 ]] &&
      { [[ -x "$source" && -x "$live" ]] || [[ ! -x "$source" && ! -x "$live" ]]; }; then
      printf 'identical\n'
    else
      printf 'divergent\n'
    fi
    return
  fi

  printf 'conflict\n'
}

list_tools_with_entries() {
  local tool_dir=""
  local tool=""

  for tool_dir in "$DOTFILES/tools"/*; do
    [[ -d "$tool_dir/config" ]] || continue
    tool="$(basename "$tool_dir")"
    tool_has_entries "$tool" && printf '%s\n' "$tool"
  done
}

print_tool_status() {
  local tool="$1"
  local detailed="$2"
  local path=""
  local state=""
  local linked=0
  local missing=0
  local identical=0
  local divergent=0
  local conflict=0
  local details=""

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    state="$(entry_state "$tool" "$path")"
    case "$state" in
    linked) linked=$((linked + 1)) ;;
    missing) missing=$((missing + 1)) ;;
    identical) identical=$((identical + 1)) ;;
    divergent) divergent=$((divergent + 1)) ;;
    conflict) conflict=$((conflict + 1)) ;;
    esac
    if [[ "$detailed" == true && "$state" != linked ]]; then
      details+="${details:+$'\n'}$path $state"
    fi
  done < <(list_entries "$tool")

  printf '%s linked=%s missing=%s identical=%s divergent=%s conflict=%s\n' \
    "$tool" "$linked" "$missing" "$identical" "$divergent" "$conflict"
  [[ -z "$details" ]] || printf '%s\n' "$details"
}

status_command() {
  local tool="${1:-}"

  if [[ -n "$tool" ]]; then
    require_tool "$tool"
    print_tool_status "$tool" true
    return
  fi

  while IFS= read -r tool; do
    print_tool_status "$tool" false
  done < <(list_tools_with_entries)
}

diff_entry() {
  local tool="$1"
  local path="$2"
  local source="$DOTFILES/tools/$tool/config/$path"
  local live="$HOME/$path"
  local state=""
  local diff_status=0

  state="$(entry_state "$tool" "$path")"
  case "$state" in
  linked | identical)
    return 1
    ;;
  divergent)
    set +e
    diff -u --label "tracked/$path" --label "live/$path" "$source" "$live"
    diff_status=$?
    set -e
    [[ "$diff_status" -le 1 ]] || fail "cannot compare Managed Config Entry: $path"
    ;;
  missing)
    printf '%s missing (tracked source exists)\n' "$path"
    ;;
  conflict)
    if [[ -L "$live" ]]; then
      printf '%s conflict -> %s\n' "$path" "$(readlink "$live")"
    elif [[ -d "$live" ]]; then
      printf '%s conflict (directory)\n' "$path"
    else
      printf '%s conflict (special file)\n' "$path"
    fi
    ;;
  esac
  return 0
}

diff_command() {
  local tool="$1"
  local requested="${2:-}"
  local path=""
  local found=false

  require_tool "$tool"
  if [[ -n "$requested" ]]; then
    require_entry "$tool" "$requested"
    if ! diff_entry "$tool" "$requested"; then
      printf 'No differences\n'
    fi
    return 0
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if diff_entry "$tool" "$path"; then
      found=true
    fi
  done < <(list_entries "$tool")

  [[ "$found" == true ]] || printf 'No differences\n'
}

stow_selection_ignore() {
  local path="$1"
  local prefix=""
  local component=""
  local escaped=""
  local alternatives=""
  local old_ifs="$IFS"

  IFS=/
  for component in $path; do
    if [[ -z "$prefix" ]]; then
      prefix="$component"
    else
      prefix="$prefix/$component"
    fi
    escaped="$(printf '%s' "$prefix" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
    alternatives+="${alternatives:+|}$escaped\$"
  done
  IFS="$old_ifs"

  printf '^(?!%s).*\n' "$alternatives"
}

restore_regular_backup() {
  local backup="$1"
  local live="$2"
  local tool="$3"
  local path="$4"
  local state=""

  state="$(entry_state "$tool" "$path")"
  if [[ "$state" == linked ]]; then
    rm "$live"
  elif [[ "$state" != missing ]]; then
    printf 'dotfiles config: cannot restore backup over unexpected target: %s\n' "$live" >&2
    return 1
  fi
  mv "$backup" "$live"
}

repair_entry() {
  local tool="$1"
  local path="$2"
  local dry_run="$3"
  local state=""
  local live="$HOME/$path"
  local backup=""
  local ignore=""
  local stow_status=0
  local final_state=""

  state="$(entry_state "$tool" "$path")"
  case "$state" in
  linked)
    printf '%s linked\n' "$path"
    return 0
    ;;
  missing | identical)
    if [[ "$dry_run" == true ]]; then
      printf 'Would repair %s (%s)\n' "$path" "$state"
      return 0
    fi
    ;;
  divergent | conflict)
    printf '%s %s (requires an explicit content decision)\n' "$path" "$state" >&2
    return 1
    ;;
  esac

  if [[ "$state" == identical ]]; then
    backup="$(mktemp "${TMPDIR:-/tmp}/dotfiles-repair.XXXXXX")"
    rm "$backup"
    mv "$live" "$backup"
  fi

  ignore="$(stow_selection_ignore "$path")"
  set +e
  stow --no-folding --restow -d "$DOTFILES/tools/$tool" -t "$HOME" \
    --ignore="$ignore" config
  stow_status=$?
  set -e

  final_state="$(entry_state "$tool" "$path")"
  if [[ "$stow_status" -ne 0 || "$final_state" != linked ]]; then
    if [[ -n "$backup" ]]; then
      restore_regular_backup "$backup" "$live" "$tool" "$path" || true
    elif [[ "$final_state" == linked ]]; then
      rm "$live"
    fi
    printf 'dotfiles config: failed to repair %s (Stow status %s)\n' "$path" "$stow_status" >&2
    return 1
  fi

  [[ -z "$backup" ]] || rm "$backup"
  printf '%s repaired\n' "$path"
}

repair_command() {
  local tool=""
  local requested=""
  local dry_run=false
  local argument=""
  local path=""
  local failed=false

  for argument in "$@"; do
    case "$argument" in
    --dry-run) dry_run=true ;;
    *)
      if [[ -z "$tool" ]]; then tool="$argument"; else requested="$argument"; fi
      ;;
    esac
  done

  require_tool "$tool"
  if [[ -n "$requested" ]]; then
    require_entry "$tool" "$requested"
    repair_entry "$tool" "$requested" "$dry_run"
    return
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    repair_entry "$tool" "$path" "$dry_run" || failed=true
  done < <(list_entries "$tool")

  if [[ "$failed" == true ]]; then
    printf 'dotfiles config: repair incomplete for %s\n' "$tool" >&2
    return 1
  fi
}

reserve_config_backup_dir() {
  local root="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/config-backups"
  local timestamp=""
  local backup=""
  local suffix=0

  [[ ! -L "$root" ]] || return 1
  mkdir -p "$root" || return 1
  chmod 700 "$root" || return 1
  timestamp="$(date '+%Y%m%d%H%M%S')" || return 1
  backup="$root/$timestamp"

  while ! mkdir "$backup" 2>/dev/null; do
    [[ -e "$backup" ]] || return 1
    suffix=$((suffix + 1))
    backup="$root/$timestamp.$suffix"
  done
  chmod 700 "$backup" || return 1
  printf '%s\n' "$backup"
}

config_backup_root() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/config-backups"
}

list_config_backups() {
  local root=""

  root="$(config_backup_root)"
  [[ ! -L "$root" ]] || fail "backup root is an unowned symlink: $root"
  if [[ ! -d "$root" ]]; then
    printf 'No Config Lifecycle backups.\n'
    return 0
  fi

  find "$root" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | LC_ALL=C sort -r
}

prune_config_backups() {
  local keep=20
  local force=false
  local argument=""
  local root=""
  local backup=""
  local name=""
  local index=0
  local found=false

  while (($#)); do
    argument="$1"
    shift
    case "$argument" in
    --keep)
      keep="${1:-}"
      shift || true
      ;;
    --keep=*) keep="${argument#--keep=}" ;;
    --force) force=true ;;
    *) fail "unsupported backups prune option: $argument" ;;
    esac
  done
  [[ "$keep" =~ ^[0-9]+$ ]] || fail "--keep requires a non-negative integer"

  root="$(config_backup_root)"
  [[ ! -L "$root" ]] || fail "backup root is an unowned symlink: $root"
  [[ -d "$root" ]] || {
    printf 'No Config Lifecycle backups.\n'
    return 0
  }

  while IFS= read -r backup; do
    [[ -n "$backup" ]] || continue
    name="$(basename "$backup")"
    [[ "$name" =~ ^[0-9]{14}(\.[0-9]+)?$ && ! -L "$backup" ]] || continue
    if [[ "$index" -ge "$keep" ]]; then
      found=true
      if [[ "$force" == true ]]; then
        /bin/rm -rf -- "$backup"
        printf 'Pruned %s\n' "$backup"
      else
        printf 'Would prune %s\n' "$backup"
      fi
    fi
    index=$((index + 1))
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print | LC_ALL=C sort -r)

  if [[ "$found" != true ]]; then
    printf 'No Config Lifecycle backups exceed retention (%s).\n' "$keep"
  elif [[ "$force" != true ]]; then
    printf 'Dry run only; repeat with --force to prune these backups.\n'
  fi
}

new_safety_backup() {
  local tool="$1"
  local path="$2"
  local backup=""
  local source="$DOTFILES/tools/$tool/config/$path"
  local live="$HOME/$path"

  backup="$(reserve_config_backup_dir)" || return 1

  if ! mkdir -p "$backup/tracked/$tool/$(dirname "$path")" "$backup/live/$(dirname "$path")"; then
    return 1
  fi
  if ! cp -p "$source" "$backup/tracked/$tool/$path" ||
    ! cp -p "$live" "$backup/live/$path"; then
    rm -rf "$backup"
    return 1
  fi
  printf '%s\n' "$backup"
}

restore_mutation_backup() {
  local backup="$1"
  local tool="$2"
  local path="$3"
  local source="$DOTFILES/tools/$tool/config/$path"
  local live="$HOME/$path"
  local state=""

  cp -p "$backup/tracked/$tool/$path" "$source"
  if [[ -L "$live" ]]; then
    state="$(entry_state "$tool" "$path")"
    if [[ "$state" == linked ]]; then
      rm "$live"
    else
      printf 'dotfiles config: refusing to overwrite unexpected target while restoring: %s\n' \
        "$live" >&2
      return 1
    fi
  elif [[ -e "$live" ]]; then
    printf 'dotfiles config: refusing to overwrite unexpected target while restoring: %s\n' \
      "$live" >&2
    return 1
  fi
  cp -p "$backup/live/$path" "$live"
}

stow_mutated_entry() {
  local tool="$1"
  local path="$2"
  local ignore=""
  local stow_status=0

  ignore="$(stow_selection_ignore "$path")"
  set +e
  stow --no-folding --restow -d "$DOTFILES/tools/$tool" -t "$HOME" \
    --ignore="$ignore" config
  stow_status=$?
  set -e

  [[ "$stow_status" -eq 0 && "$(entry_state "$tool" "$path")" == linked ]]
}

source_is_dirty() {
  local tool="$1"
  local path="$2"
  [[ -n "$(git -C "$DOTFILES" status --porcelain -- "tools/$tool/config/$path")" ]]
}

scan_capture_candidate() {
  local live="$1"
  gitleaks detect --source "$live" --no-git --redact --no-banner
}

content_command() {
  local operation="$1"
  shift
  local tool=""
  local path=""
  local dry_run=false
  local argument=""
  local state=""
  local source=""
  local live=""
  local backup=""
  local operation_label=""

  case "$operation" in
  capture) operation_label=Captured ;;
  discard) operation_label=Discarded ;;
  esac

  for argument in "$@"; do
    case "$argument" in
    --dry-run) dry_run=true ;;
    *)
      if [[ -z "$tool" ]]; then tool="$argument"; else path="$argument"; fi
      ;;
    esac
  done

  require_tool "$tool"
  require_entry "$tool" "$path"
  state="$(entry_state "$tool" "$path")"
  [[ "$state" == divergent ]] || fail "$operation requires a divergent regular file; found $state"

  source="$DOTFILES/tools/$tool/config/$path"
  live="$HOME/$path"

  if [[ "$operation" == capture ]]; then
    source_is_dirty "$tool" "$path" && fail "tracked source has uncommitted changes: $path"
    command -v gitleaks >/dev/null 2>&1 || fail "gitleaks is required for capture"
    scan_capture_candidate "$live" || fail "Gitleaks blocked capture: $path"
  fi

  if [[ "$dry_run" == true ]]; then
    printf 'Would %s %s\n' "$operation" "$path"
    return 0
  fi

  backup="$(new_safety_backup "$tool" "$path")" ||
    fail "could not create safety backup for $path"

  if [[ "$operation" == capture ]]; then
    cp -p "$live" "$source"
  fi
  rm "$live"

  if ! stow_mutated_entry "$tool" "$path"; then
    if restore_mutation_backup "$backup" "$tool" "$path"; then
      printf 'dotfiles config: %s failed while restoring the Stow link; restored the safety backup\n' \
        "$operation" >&2
    else
      printf 'dotfiles config: %s failed; live restore was blocked and the safety backup was preserved\n' \
        "$operation" >&2
    fi
    printf 'Backup: %s\n' "$backup" >&2
    return 1
  fi

  printf '%s %s\n' "$operation_label" "$path"
  printf 'Backup: %s\n' "$backup"
}

config_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

confirm_provider() {
  local provider="$1"
  local response=""

  printf 'dotfiles config: the %s provider may receive the selected config diff. Continue? [y/N] ' \
    "$provider" >&2
  read -r response
  case "$response" in
  y | Y | yes | YES | Yes) return 0 ;;
  *) return 1 ;;
  esac
}

select_agent() {
  local requested="$1"
  local has_claude=false
  local has_codex=false
  local response=""

  command -v claude >/dev/null 2>&1 && has_claude=true
  command -v codex >/dev/null 2>&1 && has_codex=true

  if [[ -n "$requested" ]]; then
    if [[ "$requested" == claude && "$has_claude" == true ]]; then
      printf 'claude\n'
      return
    fi
    if [[ "$requested" == codex && "$has_codex" == true ]]; then
      printf 'codex\n'
      return
    fi
    fail "requested agent is not installed: $requested"
  fi

  if [[ "$has_claude" == true && "$has_codex" != true ]]; then
    printf 'claude\n'
    return
  fi
  if [[ "$has_codex" == true && "$has_claude" != true ]]; then
    printf 'codex\n'
    return
  fi
  if [[ "$has_claude" != true && "$has_codex" != true ]]; then
    fail "neither Claude nor Codex is installed"
  fi

  printf 'Select agent [claude/codex]: ' >&2
  read -r response
  case "$response" in
  claude | codex) printf '%s\n' "$response" ;;
  *) fail "invalid agent selection: $response" ;;
  esac
}

new_resolve_backup() {
  local tool="$1"
  local path="$2"
  local backup=""
  local source="$DOTFILES/tools/$tool/config/$path"
  local live="$HOME/$path"

  backup="$(reserve_config_backup_dir)" || return 1

  if ! mkdir -p "$backup/tracked/$tool/$(dirname "$path")" "$backup/live/$(dirname "$path")"; then
    return 1
  fi
  if ! cp -p "$source" "$backup/tracked/$tool/$path"; then
    rm -rf "$backup"
    return 1
  fi
  if [[ -L "$live" ]]; then
    if ! cp -Pp "$live" "$backup/live/$path"; then
      rm -rf "$backup"
      return 1
    fi
  elif [[ -f "$live" ]]; then
    if ! cp -p "$live" "$backup/live/$path"; then
      rm -rf "$backup"
      return 1
    fi
  fi
  printf '%s\n' "$backup"
}

resolve_context() {
  local tool="$1"
  local path="$2"
  local state="$3"
  local source_relative="tools/$tool/config/$path"
  local git_condition=""
  local difference=""

  git_condition="$(git -C "$DOTFILES" status --short -- "$source_relative")"
  [[ -n "$git_condition" ]] || git_condition=clean
  difference="$(diff_entry "$tool" "$path" || true)"

  cat <<EOF
Resolve one Managed Config Entry in the Dotfiles Repository.

State: $state
Tracked: $source_relative
Live: ~/$path
Git: $git_condition

Difference:
$difference

Work with the operator to decide the best resolution. You may edit the tracked
or live file directly or use the Dotfiles Command. Finish with the live target
linked to the tracked source.
EOF
}

run_agent() {
  local provider="$1"
  local context="$2"

  case "$provider" in
  claude)
    (cd "$DOTFILES" && claude --dangerously-skip-permissions "$context")
    ;;
  codex)
    (cd "$DOTFILES" && codex --dangerously-bypass-approvals-and-sandbox "$context")
    ;;
  esac
}

resolve_command() {
  local tool=""
  local path=""
  local requested_agent=""
  local argument=""
  local provider=""
  local state=""
  local live=""
  local backup=""
  local context=""
  local agent_status=0
  local final_state=""

  while (($#)); do
    argument="$1"
    shift
    case "$argument" in
    --agent)
      requested_agent="${1:-}"
      shift || true
      ;;
    --agent=*) requested_agent="${argument#--agent=}" ;;
    *)
      if [[ -z "$tool" ]]; then tool="$argument"; else path="$argument"; fi
      ;;
    esac
  done

  config_is_interactive || fail "resolve requires an interactive terminal"
  require_tool "$tool"
  require_entry "$tool" "$path"
  state="$(entry_state "$tool" "$path")"
  case "$state" in
  divergent | conflict) ;;
  missing | identical) fail "use config repair for $state state: $path" ;;
  linked) fail "Managed Config Entry is already linked: $path" ;;
  esac

  live="$HOME/$path"
  if [[ -d "$live" || (-e "$live" && ! -f "$live" && ! -L "$live") ]]; then
    fail "resolve does not automate directory or special-file conflicts: $path"
  fi

  provider="$(select_agent "$requested_agent")"
  confirm_provider "$provider" || fail "provider confirmation declined"

  context="$(resolve_context "$tool" "$path" "$state")"
  backup="$(new_resolve_backup "$tool" "$path")" ||
    fail "could not create resolution backup for $path"
  printf 'Backup: %s\n' "$backup"
  case "$provider" in
  claude) printf 'Launching Claude with --dangerously-skip-permissions.\n' ;;
  codex) printf 'Launching Codex with --dangerously-bypass-approvals-and-sandbox.\n' ;;
  esac

  set +e
  run_agent "$provider" "$context"
  agent_status=$?
  set -e

  final_state="$(entry_state "$tool" "$path")"
  printf 'Final state: %s\n' "$final_state"
  git -C "$DOTFILES" diff -- "tools/$tool/config/$path"

  if [[ "$final_state" == linked ]]; then
    if [[ "$agent_status" -ne 0 ]]; then
      printf 'dotfiles config: %s exited with status %s, but final state is linked\n' \
        "$provider" "$agent_status" >&2
    fi
    return 0
  fi

  printf 'dotfiles config: resolve incomplete; backup preserved at %s\n' "$backup" >&2
  return 1
}

main() {
  local command_name="${1:-}"
  shift || true

  case "$command_name" in
  status) status_command "$@" ;;
  diff) diff_command "$@" ;;
  repair) repair_command "$@" ;;
  capture) content_command capture "$@" ;;
  discard) content_command discard "$@" ;;
  resolve) resolve_command "$@" ;;
  backups)
    case "${1:-}" in
    list) list_config_backups ;;
    prune)
      shift
      prune_config_backups "$@"
      ;;
    *) fail "backups requires list or prune" ;;
    esac
    ;;
  *) fail "unsupported config command: $command_name" ;;
  esac
}

if [[ "${DOTFILES_CONFIG_NO_MAIN:-false}" != true ]]; then
  main "$@"
fi
