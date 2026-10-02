#!/usr/bin/env bash
# shellcheck disable=SC2016 # Quoted snippets are evaluated by Fish.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FISH=/opt/homebrew/bin/fish
PORTS="$ROOT_DIR/tools/fish/config/.config/fish/functions/ports.fish"
IMG2JPG="$ROOT_DIR/tools/fish/config/.config/fish/functions/img2jpg.fish"
IMGOPTIMIZE="$ROOT_DIR/tools/fish/config/.config/fish/functions/imgoptimize.fish"
CLI_ABBRS="$ROOT_DIR/tools/fish/config/.config/fish/conf.d/04_cli-abbrs.fish"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$TMP_DIR/bin"
for fake_command in magick eza ggrep; do
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$TMP_DIR/bin/$fake_command"
  chmod +x "$TMP_DIR/bin/$fake_command"
done

fail() {
  printf 'Fish validation test: %s\n' "$*" >&2
  exit 1
}

if PORTS="$PORTS" "$FISH" --no-config -c \
  'source "$PORTS"; ports 0' >"$TMP_DIR/ports.out" 2>"$TMP_DIR/ports.err"; then
  fail "ports accepted zero"
fi
grep -F 'between 1 and 65535' "$TMP_DIR/ports.err" >/dev/null ||
  fail "ports did not explain its valid range"

if IMGOPTIMIZE="$IMGOPTIMIZE" "$FISH" --no-config -c \
  'source "$IMGOPTIMIZE"; imgoptimize 0' \
  >"$TMP_DIR/imgoptimize.out" 2>"$TMP_DIR/imgoptimize.err"; then
  fail "imgoptimize accepted a zero dimension"
fi
grep -F 'positive integer' "$TMP_DIR/imgoptimize.err" >/dev/null ||
  fail "imgoptimize did not explain its dimension constraint"

touch "$TMP_DIR/input.png"
if PATH="$TMP_DIR/bin:$PATH" IMG2JPG="$IMG2JPG" INPUT_IMAGE="$TMP_DIR/input.png" \
  "$FISH" --no-config -c \
  'source "$IMG2JPG"; img2jpg --max-width 0 "$INPUT_IMAGE"' \
  >"$TMP_DIR/img2jpg.out" 2>"$TMP_DIR/img2jpg.err"; then
  fail "img2jpg accepted a zero dimension"
fi
grep -F 'positive integer' "$TMP_DIR/img2jpg.err" >/dev/null ||
  fail "img2jpg did not explain its dimension constraint"

EXTRACT="$ROOT_DIR/tools/fish/config/.config/fish/completions/extract.fish"
mkdir -p "$TMP_DIR/archives/nested"
touch "$TMP_DIR/archives/a.tar.zst" "$TMP_DIR/archives/b.xz" "$TMP_DIR/archives/c.zst" "$TMP_DIR/archives/notes.txt"
extract_candidates="$(EXTRACT="$EXTRACT" ARCHIVES="$TMP_DIR/archives" "$FISH" --no-config -c \
  'source "$EXTRACT"; complete -C "extract $ARCHIVES/"' </dev/null | cut -f1 | xargs -n1 basename | tr '\n' ' ')"
[[ "$extract_candidates" == "a.tar.zst b.xz c.zst nested notes.txt " ]] ||
  fail "extract completion did not rank archives before other files: $extract_candidates"

PATH="$TMP_DIR/bin:$PATH" CLI_ABBRS="$CLI_ABBRS" "$FISH" --no-config --interactive -c \
  'source "$CLI_ABBRS"
    abbr -q ls
    and abbr -q grep
    and not abbr -q ll' </dev/null ||
  fail "interactive CLI shortcuts were not registered"

LL="$ROOT_DIR/tools/fish/config/.config/fish/functions/ll.fish"
cat >"$TMP_DIR/bin/eza" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$EZA_ARGS"
exit "${EZA_STATUS:-0}"
SH

fish_home="$TMP_DIR/home with spaces"
fish_config="$fish_home/.config/fish"
mkdir -p "$fish_config/conf.d" "$fish_config/functions"
ln -s "$CLI_ABBRS" "$fish_config/conf.d/04_cli-abbrs.fish"

printf '%s\n' --icons=auto --color=auto --group-directories-first \
  --octal-permissions --git -alh --classify=auto "$fish_home" --sort=size \
  >"$TMP_DIR/expected-eza.args"

for link_state in missing linked; do
  if [[ "$link_state" == linked ]]; then
    ln -s "$LL" "$fish_config/functions/ll.fish"
  fi

  HOME="$fish_home" XDG_CONFIG_HOME="$fish_home/.config" PATH="$TMP_DIR/bin:/usr/bin:/bin" \
    CLI_ABBRS="$fish_config/conf.d/04_cli-abbrs.fish" EZA_ARGS="$TMP_DIR/eza.args" \
    "$FISH" --no-config --interactive -c \
    'set -p fish_function_path "$__fish_config_dir/functions"
      functions ll >/dev/null
      source "$CLI_ABBRS"
      ll "$HOME" --sort=size' </dev/null ||
    fail "ll failed with a $link_state function link"
  cmp -s "$TMP_DIR/expected-eza.args" "$TMP_DIR/eza.args" ||
    fail "ll did not use eza with the expected options and arguments ($link_state link)"
  rm "$TMP_DIR/eza.args"
done

set +e
PATH="$TMP_DIR/bin:$PATH" LL="$LL" EZA_ARGS="$TMP_DIR/eza.args" EZA_STATUS=37 \
  "$FISH" --no-config -c 'source "$LL"; ll' </dev/null
ll_status=$?
set -e
[[ "$ll_status" -eq 37 ]] || fail "ll did not preserve eza's exit status"

CLI_ABBRS="$CLI_ABBRS" "$FISH" --no-config -c \
  'function ll; echo caller; end; source "$CLI_ABBRS"; test (ll) = caller' </dev/null ||
  fail "CLI configuration replaced ll in a noninteractive shell"

mkdir -p "$TMP_DIR/listing"
touch "$TMP_DIR/listing/entry"
PATH=/usr/bin:/bin LL="$LL" LISTING="$TMP_DIR/listing" "$FISH" --no-config -c \
  'source "$LL"; ll "$LISTING"' >"$TMP_DIR/ll.out" 2>&1 ||
  fail "ll did not fall back to ls without eza"
grep -F entry "$TMP_DIR/ll.out" >/dev/null || fail "ll fallback did not list the directory"

HOME="$fish_home" XDG_CONFIG_HOME="$fish_home/.config" PATH=/usr/bin:/bin \
  CLI_ABBRS="$fish_config/conf.d/04_cli-abbrs.fish" LISTING="$TMP_DIR/listing" \
  "$FISH" --no-config --interactive -c \
  'set -p fish_function_path "$__fish_config_dir/functions"; source "$CLI_ABBRS"; ll "$LISTING"' \
  >"$TMP_DIR/ll.out" 2>&1 </dev/null || fail "interactive ll failed without eza"
grep -F entry "$TMP_DIR/ll.out" >/dev/null || fail "interactive ll fallback did not list the directory"

rm "$fish_config/functions/ll.fish"
printf '%s\n' 'function ll; echo custom; end' >"$fish_config/functions/ll.fish"
HOME="$fish_home" XDG_CONFIG_HOME="$fish_home/.config" CLI_ABBRS="$fish_config/conf.d/04_cli-abbrs.fish" \
  "$FISH" --no-config --interactive -c \
  'set -p fish_function_path "$__fish_config_dir/functions"; source "$CLI_ABBRS"; test (ll) = custom' </dev/null ||
  fail "CLI configuration overrode an existing ll function file"
