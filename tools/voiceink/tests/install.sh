#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/voiceink-install.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT
fixture_root="$fixture_dir/repository"
fixture_home="$fixture_dir/home with spaces"
mkdir -p "$fixture_root/tools/voiceink" "$fixture_dir/homebrew/bin" "$fixture_home"
cp -R "$ROOT_DIR/tools/voiceink/config" "$fixture_root/tools/voiceink/config"
cp "$ROOT_DIR/tools/lib.sh" "$fixture_root/tools/lib.sh"

fail() {
  printf 'voiceink install test: %s\n' "$*" >&2
  exit 1
}

cat >"$fixture_dir/homebrew/bin/mise" <<'MISE'
#!/usr/bin/env bash
[[ "$*" == 'which codex' && "${VOICEINK_TEST_CODEX:-present}" == present ]]
MISE
chmod +x "$fixture_dir/homebrew/bin/mise"

install_for() {
  HOME="$1" DOTFILES="$fixture_root" HOMEBREW_PREFIX="$fixture_dir/homebrew" \
    /bin/bash "$ROOT_DIR/tools/voiceink/install.sh"
}

skipped_home="$fixture_dir/missing-codex"
mkdir -p "$skipped_home"
VOICEINK_TEST_CODEX=missing install_for "$skipped_home" >"$fixture_dir/skipped.out" 2>&1
[[ ! -e "$skipped_home/.local" ]] || fail 'missing Codex caused installation'
grep -F 'skipping' "$fixture_dir/skipped.out" >/dev/null

install_for "$fixture_home" >"$fixture_dir/install.out" 2>"$fixture_dir/install.err"
runtime="$fixture_home/.local/share/voiceink-codex"
[[ -d "$runtime" && ! -L "$runtime" ]] || fail 'runtime directory was folded'
for name in run.sh config.toml; do
  [[ -L "$runtime/$name" ]] || fail "$name was not stowed"
  cmp "$runtime/$name" "$ROOT_DIR/tools/voiceink/config/.local/share/voiceink-codex/$name"
done
[[ "$(readlink "$runtime/auth.json")" == "$fixture_home/.codex/auth.json" ]] ||
  fail 'authentication link has the wrong target'
for name in comment-style communicate-clearly; do
  [[ "$(readlink "$runtime/skills/$name")" == "$fixture_home/.agents/skills/$name" ]] ||
    fail "$name has the wrong target"
done
grep -F 'run codex login' "$fixture_dir/install.err" >/dev/null
grep -F 'run dotfiles tool apply skills' "$fixture_dir/install.err" >/dev/null

mkdir -p "$fixture_home/.codex" "$fixture_home/.local/share/mise/shims"
printf '{}\n' >"$fixture_home/.codex/auth.json"
for name in comment-style communicate-clearly; do
  mkdir -p "$fixture_home/.agents/skills/$name/references"
  printf '%s\n' "Instructions for $name" >"$fixture_home/.agents/skills/$name/SKILL.md"
  printf '%s\n' 'Reference text' >"$fixture_home/.agents/skills/$name/references/example.md"
  [[ "$(cat "$runtime/skills/$name/references/example.md")" == 'Reference text' ]] ||
    fail "$name references are unavailable"
done
printf 'cached state\n' >"$runtime/runtime-state"
install_for "$fixture_home" >"$fixture_dir/reinstall.out" 2>"$fixture_dir/reinstall.err"
[[ "$(cat "$runtime/runtime-state")" == 'cached state' ]] || fail 'reinstall removed runtime state'
[[ ! -e "$fixture_root/tools/voiceink/config/.local/share/voiceink-codex/runtime-state" ]] ||
  fail 'runtime state entered the Stow package'
! grep -F 'unavailable' "$fixture_dir/reinstall.err" >/dev/null || fail 'valid sources were rejected'

cat >"$fixture_home/.local/share/mise/shims/codex" <<'CODEX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$CODEX_HOME" "$@" >"$VOICEINK_TEST_CAPTURE"
printf 'Progress output\n' >&2
printf 'Rewritten message\n'
exit "${VOICEINK_TEST_STATUS:-0}"
CODEX
chmod +x "$fixture_home/.local/share/mise/shims/codex"

prompt=$'Keep $HOME, `code`, "quotes", and a newline.\nSecond line.'
capture="$fixture_dir/codex-args"
for attempt in first second; do
  if [[ "$attempt" == second ]]; then
    printf 'Updated instructions\n' >>"$fixture_home/.agents/skills/comment-style/SKILL.md"
  fi
  HOME="$fixture_home" VOICEINK_FULL_PROMPT="$prompt" VOICEINK_TEST_CAPTURE="$capture" \
    PATH=/usr/bin:/bin /bin/bash "$runtime/run.sh" \
    >"$fixture_dir/run.out" 2>"$fixture_dir/run.err"
  [[ "$(cat "$fixture_dir/run.out")" == 'Rewritten message' ]] || fail 'stdout contains extra output'
  grep -Fx 'Progress output' "$fixture_dir/run.err" >/dev/null
  python3 - "$capture" "$runtime" "$prompt" <<'PY'
import sys
from pathlib import Path

capture, runtime, prompt = sys.argv[1:]
args = Path(capture).read_bytes().decode().split('\0')[:-1]
assert args[:-1] == [runtime, '-C', runtime, 'exec', '--skip-git-repo-check', '--ephemeral', '--color', 'never']
assert args[-1].endswith(prompt)
assert args[-1].count('<skill>') == 2
for name in ['comment-style', 'communicate-clearly']:
    path = f'{runtime}/skills/{name}/SKILL.md'
    assert Path(path).read_text() in args[-1]
    assert f'<path>{path}</path>' in args[-1]
PY
done

status=0
HOME="$fixture_home" VOICEINK_FULL_PROMPT="$prompt" VOICEINK_TEST_CAPTURE="$capture" \
  VOICEINK_TEST_STATUS=7 /bin/bash "$runtime/run.sh" >/dev/null 2>&1 || status=$?
[[ "$status" -eq 7 ]] || fail 'Codex failure status was lost'

rm "$capture"
if HOME="$fixture_home" VOICEINK_TEST_CAPTURE="$capture" \
  env -u VOICEINK_FULL_PROMPT /bin/bash "$runtime/run.sh" >"$fixture_dir/missing.out" 2>&1; then
  fail 'missing prompt succeeded'
fi
[[ ! -e "$capture" ]] || fail 'missing prompt invoked Codex'
rm "$fixture_home/.agents/skills/comment-style/SKILL.md"
if HOME="$fixture_home" VOICEINK_FULL_PROMPT="$prompt" VOICEINK_TEST_CAPTURE="$capture" \
  /bin/bash "$runtime/run.sh" >"$fixture_dir/missing.out" 2>&1; then
  fail 'missing skill succeeded'
fi
[[ ! -e "$capture" ]] || fail 'missing skill invoked Codex'

for conflict in auth skill directory config; do
  conflict_home="$fixture_dir/conflict-$conflict"
  conflict_runtime="$conflict_home/.local/share/voiceink-codex"
  mkdir -p "$conflict_runtime"
  case "$conflict" in
  auth) printf 'local auth state\n' >"$conflict_runtime/auth.json" ;;
  skill)
    mkdir -p "$conflict_runtime/skills"
    ln -s "$fixture_dir/foreign-skill" "$conflict_runtime/skills/comment-style"
    ;;
  directory) ln -s "$fixture_dir/foreign-skills" "$conflict_runtime/skills" ;;
  config) printf 'local settings\n' >"$conflict_runtime/config.toml" ;;
  esac
  if install_for "$conflict_home" >"$fixture_dir/conflict.out" 2>&1; then
    fail "$conflict conflict was accepted"
  fi
  [[ ! -e "$conflict_runtime/run.sh" ]] || fail "$conflict conflict caused partial installation"
  case "$conflict" in
  auth) [[ "$(cat "$conflict_runtime/auth.json")" == 'local auth state' ]] ;;
  skill) [[ "$(readlink "$conflict_runtime/skills/comment-style")" == "$fixture_dir/foreign-skill" ]] ;;
  directory) [[ "$(readlink "$conflict_runtime/skills")" == "$fixture_dir/foreign-skills" ]] ;;
  config) [[ "$(cat "$conflict_runtime/config.toml")" == 'local settings' ]] ;;
  esac
done

DOTFILES="$ROOT_DIR" "$ROOT_DIR/dotfiles" tool list | grep -Fx voiceink >/dev/null ||
  fail 'VoiceInk is missing from the Tool Catalog'
printf 'VoiceInk installation and command tests: passed\n'
