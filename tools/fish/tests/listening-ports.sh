#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by Fish.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH=/opt/homebrew/bin/fish
FISH_ROOT="$ROOT_DIR/tools/fish/config/.config/fish"
HELPER="$FISH_ROOT/functions/__fish_listening_ports.fish"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'Fish listening-ports test: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/lsof" <<'LSOF'
#!/bin/sh
printf '%s\n' \
  'COMMAND   PID     USER   FD   TYPE DEVICE SIZE/OFF NODE NAME' \
  'postgres  222 lurrutia    7u  IPv4    0x1      0t0  TCP *:5432 (LISTEN)' \
  'node    12345 lurrutia   23u  IPv4    0x2      0t0  TCP 127.0.0.1:3000 (LISTEN)' \
  'node    12345 lurrutia   24u  IPv6    0x3      0t0  TCP [::1]:3000 (LISTEN)'
LSOF
chmod +x "$TMP_DIR/bin/lsof"

run_fish() {
  PATH="$TMP_DIR/bin:/usr/bin:/bin" HELPER="$HELPER" FISH_ROOT="$FISH_ROOT" "$FISH" --no-config -c "$1" </dev/null
}

rows="$(run_fish 'source "$HELPER"; __fish_listening_ports')"
[[ "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')" -eq 2 ]] ||
  fail "IPv4 and IPv6 listeners on one port were not collapsed: $rows"
[[ "$(printf '%s\n' "$rows" | head -n 1)" == $'3000\tnode\t12345\t'* ]] ||
  fail "rows are not sorted by port with command and pid columns: $rows"
[[ "$(printf '%s\n' "$rows" | tail -n 1)" == $'5432\tpostgres\t222\t*:5432' ]] ||
  fail "the address column was not preserved: $rows"

for command_name in ports killport; do
  candidates="$(run_fish 'source "$HELPER"; source "$FISH_ROOT/completions/'"$command_name"'.fish"; complete -C "'"$command_name"' "')"
  [[ "$candidates" == *$'3000\tnode (12345)'* && "$candidates" == *$'5432\tpostgres (222)'* ]] ||
    fail "$command_name completion did not describe listening ports: $candidates"
done
