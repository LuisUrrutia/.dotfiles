#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2088 # Quoted snippets and tilde are fixture literals.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
FIXTURE_ROOT="$TMP_DIR/repository"
HOME_DIR="$TMP_DIR/home"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  printf 'config lifecycle test: %s\n' "$*" >&2
  exit 1
}

mkdir -p \
  "$FIXTURE_ROOT/cli" \
  "$FIXTURE_ROOT/config" \
  "$FIXTURE_ROOT/tools/fixture/config/.config/fixture" \
  "$HOME_DIR/.config/fixture"
cp "$ROOT_DIR/dotfiles" "$FIXTURE_ROOT/dotfiles"
cp "$ROOT_DIR"/cli/*.sh "$FIXTURE_ROOT/cli/"
cp "$ROOT_DIR/config/run.sh" "$FIXTURE_ROOT/config/run.sh"
chmod +x "$FIXTURE_ROOT/dotfiles" "$FIXTURE_ROOT/config/run.sh"

printf '%s\n' linked >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/linked.txt"
printf '%s\n' missing >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/missing.txt"
printf '%s\n' identical >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/identical.txt"
printf '%s\n' tracked >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/divergent.txt"
printf '%s\n' conflict >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/conflict.txt"
printf '%s\n' ignored >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/ignored.txt"
printf '%s\n' untracked >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/untracked.txt"
printf '%s\n' spaced >"$FIXTURE_ROOT/tools/fixture/config/.config/fixture/space name.txt"
printf '%s\n' '^/\.config/fixture/ignored\.txt$' >"$FIXTURE_ROOT/tools/fixture/config/.stow-local-ignore"

git -C "$FIXTURE_ROOT" init -q
git -C "$FIXTURE_ROOT" config user.name Fixture
git -C "$FIXTURE_ROOT" config user.email fixture@example.com
git -C "$FIXTURE_ROOT" config commit.gpgsign false
git -C "$FIXTURE_ROOT" add dotfiles config/run.sh tools/fixture/config
git -C "$FIXTURE_ROOT" reset -q tools/fixture/config/.config/fixture/untracked.txt
git -C "$FIXTURE_ROOT" commit -qm fixture

ln -s "$FIXTURE_ROOT/tools/fixture/config/.config/fixture/linked.txt" \
  "$HOME_DIR/.config/fixture/linked.txt"
ln -s "$FIXTURE_ROOT/tools/fixture/config/.config/fixture/space name.txt" \
  "$HOME_DIR/.config/fixture/space name.txt"
cp "$FIXTURE_ROOT/tools/fixture/config/.config/fixture/identical.txt" \
  "$HOME_DIR/.config/fixture/identical.txt"
printf '%s\n' live >"$HOME_DIR/.config/fixture/divergent.txt"
ln -s "$TMP_DIR/foreign.txt" "$HOME_DIR/.config/fixture/conflict.txt"
printf '%s\n' changed-but-ignored >"$HOME_DIR/.config/fixture/ignored.txt"
printf '%s\n' changed-but-untracked >"$HOME_DIR/.config/fixture/untracked.txt"

status_output="$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config status fixture)"
[[ "$status_output" != *'.config/fixture/linked.txt linked'* ]] || fail "healthy entry made tool status noisy"
[[ "$status_output" == *'.config/fixture/missing.txt missing'* ]] || fail "missing state was not classified"
[[ "$status_output" == *'.config/fixture/identical.txt identical'* ]] || fail "identical state was not classified"
[[ "$status_output" == *'.config/fixture/divergent.txt divergent'* ]] || fail "divergent state was not classified"
[[ "$status_output" == *'.config/fixture/conflict.txt conflict'* ]] || fail "broken foreign link was not conflict"
[[ "$status_output" != *'ignored.txt'* ]] || fail "ignored entry entered the catalog"
[[ "$status_output" != *'untracked.txt'* ]] || fail "untracked entry entered the catalog"
[[ "$status_output" == *'linked=2 missing=1 identical=1 divergent=1 conflict=1'* ]] ||
  fail "tool status lacks stable counts"

all_status="$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config status)"
[[ "$all_status" == 'fixture linked=2 missing=1 identical=1 divergent=1 conflict=1' ]] ||
  fail "all-tools status is not concise"

cmp_bin="$TMP_DIR/cmp-bin"
mkdir -p "$cmp_bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 2' >"$cmp_bin/cmp"
chmod +x "$cmp_bin/cmp"
set +e
PATH="$cmp_bin:$PATH" HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config status fixture \
  >"$TMP_DIR/cmp-error.out" 2>"$TMP_DIR/cmp-error.err"
cmp_error_status=$?
set -e
[[ "$cmp_error_status" -eq 1 ]] || fail "Config Status classified a comparison error as drift"
grep -F 'cannot compare tracked and live files' "$TMP_DIR/cmp-error.err" >/dev/null ||
  fail "Config Status hid a comparison error"

before_git="$(git -C "$FIXTURE_ROOT" status --short)"
before_live="$(find "$HOME_DIR" -type f -o -type l | sort | while IFS= read -r entry; do
  if [[ -L "$entry" ]]; then
    printf 'link %s %s\n' "$entry" "$(readlink "$entry")"
  else
    shasum -a 256 "$entry"
  fi
done)"

diff_output="$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config diff fixture .config/fixture/divergent.txt)"
[[ "$diff_output" == *'-tracked'* && "$diff_output" == *'+live'* ]] ||
  fail "Config Diff did not show divergent content"

identical_diff="$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config diff fixture .config/fixture/identical.txt)"
[[ "$identical_diff" == 'No differences' ]] || fail "identical Config Diff was not concise"
space_diff="$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config diff fixture '.config/fixture/space name.txt')"
[[ "$space_diff" == 'No differences' ]] || fail "Config path containing spaces was not preserved"

conflict_diff="$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config diff fixture .config/fixture/conflict.txt)"
[[ "$conflict_diff" == *'conflict'* && "$conflict_diff" == *"$TMP_DIR/foreign.txt"* ]] ||
  fail "Config Diff followed or hid a foreign symlink"

[[ "$(git -C "$FIXTURE_ROOT" status --short)" == "$before_git" ]] || fail "Config inspection changed Git state"
after_live="$(find "$HOME_DIR" -type f -o -type l | sort | while IFS= read -r entry; do
  if [[ -L "$entry" ]]; then
    printf 'link %s %s\n' "$entry" "$(readlink "$entry")"
  else
    shasum -a 256 "$entry"
  fi
done)"
[[ "$after_live" == "$before_live" ]] || fail "Config inspection changed live state"

for invalid_path in /absolute '~/.config/fixture/divergent.txt' ../escape .config/../escape .config//escape; do
  set +e
  HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config diff fixture "$invalid_path" \
    >"$TMP_DIR/invalid.out" 2>"$TMP_DIR/invalid.err"
  invalid_status=$?
  set -e
  [[ "$invalid_status" -ne 0 ]] || fail "invalid path was accepted: $invalid_path"
done

dry_run_before="$(find "$HOME_DIR" -type f -o -type l | sort | while IFS= read -r entry; do
  if [[ -L "$entry" ]]; then printf 'link %s %s\n' "$entry" "$(readlink "$entry")"; else shasum -a 256 "$entry"; fi
done)"
set +e
HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config repair fixture --dry-run \
  >"$TMP_DIR/repair-dry.out" 2>"$TMP_DIR/repair-dry.err"
repair_dry_status=$?
set -e
[[ "$repair_dry_status" -eq 1 ]] || fail "blocked tool-wide Repair dry-run did not fail"
grep -F 'Would repair .config/fixture/missing.txt (missing)' "$TMP_DIR/repair-dry.out" >/dev/null ||
  fail "Repair dry-run omitted missing entry"
grep -F 'Would repair .config/fixture/identical.txt (identical)' "$TMP_DIR/repair-dry.out" >/dev/null ||
  fail "Repair dry-run omitted identical entry"
dry_run_after="$(find "$HOME_DIR" -type f -o -type l | sort | while IFS= read -r entry; do
  if [[ -L "$entry" ]]; then printf 'link %s %s\n' "$entry" "$(readlink "$entry")"; else shasum -a 256 "$entry"; fi
done)"
[[ "$dry_run_after" == "$dry_run_before" ]] || fail "Repair dry-run mutated live state"

set +e
HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config repair fixture \
  >"$TMP_DIR/repair.out" 2>"$TMP_DIR/repair.err"
repair_status=$?
set -e
[[ "$repair_status" -eq 1 ]] || fail "tool-wide Repair hid remaining drift"
[[ "$(HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config status fixture)" == *'linked=4 missing=0 identical=0 divergent=1 conflict=1'* ]] ||
  fail "Repair did not independently restore mechanical entries"
[[ "$(<"$HOME_DIR/.config/fixture/divergent.txt")" == live ]] || fail "Repair changed divergent content"
[[ "$(readlink "$HOME_DIR/.config/fixture/conflict.txt")" == "$TMP_DIR/foreign.txt" ]] ||
  fail "Repair changed conflicting symlink"

HOME="$HOME_DIR" "$FIXTURE_ROOT/dotfiles" config repair fixture .config/fixture/missing.txt >/dev/null

fake_bin="$TMP_DIR/bin"
data_home="$TMP_DIR/data"
gitleaks_log="$TMP_DIR/gitleaks.log"
mkdir -p "$fake_bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >>"$GITLEAKS_LOG"' \
  'exit "${GITLEAKS_STATUS:-0}"' \
  >"$fake_bin/gitleaks"
chmod +x "$fake_bin/gitleaks"

source_path="$FIXTURE_ROOT/tools/fixture/config/.config/fixture/divergent.txt"
live_path="$HOME_DIR/.config/fixture/divergent.txt"

PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" "$FIXTURE_ROOT/dotfiles" \
  config capture fixture .config/fixture/divergent.txt --dry-run >"$TMP_DIR/capture-dry.out"
grep -F 'Would capture .config/fixture/divergent.txt' "$TMP_DIR/capture-dry.out" >/dev/null ||
  fail "Capture dry-run omitted its plan"
[[ "$(<"$source_path")" == tracked && "$(<"$live_path")" == live ]] ||
  fail "Capture dry-run mutated content"
[[ ! -e "$data_home/dotfiles/config-backups" ]] || fail "Capture dry-run created a backup directory"

printf '%s\n' dirty >"$source_path"
set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" "$FIXTURE_ROOT/dotfiles" \
  config capture fixture .config/fixture/divergent.txt \
  >"$TMP_DIR/capture-dirty.out" 2>"$TMP_DIR/capture-dirty.err"
dirty_status=$?
set -e
[[ "$dirty_status" -eq 1 ]] || fail "Capture accepted a dirty tracked source"
[[ "$(<"$source_path")" == dirty && "$(<"$live_path")" == live ]] ||
  fail "blocked dirty Capture mutated content"
printf '%s\n' tracked >"$source_path"

set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" GITLEAKS_STATUS=1 "$FIXTURE_ROOT/dotfiles" \
  config capture fixture .config/fixture/divergent.txt \
  >"$TMP_DIR/capture-secret.out" 2>"$TMP_DIR/capture-secret.err"
secret_status=$?
set -e
[[ "$secret_status" -eq 1 ]] || fail "Capture ignored a Gitleaks finding"
[[ "$(<"$source_path")" == tracked && "$(<"$live_path")" == live ]] ||
  fail "blocked secret Capture mutated content"

blocked_data="$TMP_DIR/blocked-data"
printf '%s\n' blocker >"$blocked_data"
set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$blocked_data" \
  GITLEAKS_LOG="$gitleaks_log" "$FIXTURE_ROOT/dotfiles" \
  config capture fixture .config/fixture/divergent.txt \
  >"$TMP_DIR/capture-backup-failure.out" 2>"$TMP_DIR/capture-backup-failure.err"
backup_failure_status=$?
set -e
[[ "$backup_failure_status" -eq 1 ]] || fail "Capture continued after backup creation failed"
[[ "$(<"$source_path")" == tracked && "$(<"$live_path")" == live ]] ||
  fail "failed safety backup allowed Capture to mutate content"
grep -F 'could not create safety backup' "$TMP_DIR/capture-backup-failure.err" >/dev/null ||
  fail "Capture hid its safety backup failure"

chmod +x "$live_path"
capture_output="$(PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" "$FIXTURE_ROOT/dotfiles" \
  config capture fixture .config/fixture/divergent.txt)"
backup_path="${capture_output##*Backup: }"
[[ -d "$backup_path" ]] || fail "Capture did not report an existing safety backup"
[[ "$(<"$source_path")" == live ]] || fail "Capture did not copy live content into Git"
[[ -x "$source_path" ]] || fail "Capture did not preserve Git executable intent"
[[ -L "$live_path" ]] || fail "Capture did not restore the Stow link"
git -C "$FIXTURE_ROOT" status --short -- "$source_path" | grep -F ' M ' >/dev/null ||
  fail "Git did not observe captured content"
grep -F -- "--source $live_path" "$gitleaks_log" >/dev/null ||
  fail "Capture did not scan the live candidate"

printf '%s\n' tracked >"$source_path"
rm "$live_path"
printf '%s\n' discard-me >"$live_path"
discard_output="$(PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" "$FIXTURE_ROOT/dotfiles" \
  config discard fixture .config/fixture/divergent.txt)"
discard_backup="${discard_output##*Backup: }"
[[ -d "$discard_backup" ]] || fail "Discard did not report an existing safety backup"
[[ "$(<"$discard_backup/live/.config/fixture/divergent.txt")" == discard-me ]] ||
  fail "Discard backup does not contain the live file"
[[ -L "$live_path" && "$(<"$live_path")" == tracked ]] || fail "Discard did not restore tracked state"

rm "$live_path"
printf '%s\n' rollback-live >"$live_path"
printf '%s\n' rollback-source >"$source_path"
git -C "$FIXTURE_ROOT" add "$source_path"
git -C "$FIXTURE_ROOT" commit -qm 'prepare rollback fixture'
printf '%s\n' candidate >"$live_path"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ -n "${STOW_CONCURRENT_TARGET:-}" ]]; then' \
  '  if [[ -n "${STOW_CONCURRENT_LINK:-}" ]]; then' \
  '    ln -s "$STOW_CONCURRENT_LINK" "$STOW_CONCURRENT_TARGET"' \
  '  else' \
  '    printf "concurrent state\\n" >"$STOW_CONCURRENT_TARGET"' \
  '  fi' \
  'fi' \
  'exit 9' \
  >"$fake_bin/stow"
chmod +x "$fake_bin/stow"
set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" "$FIXTURE_ROOT/dotfiles" \
  config capture fixture .config/fixture/divergent.txt \
  >"$TMP_DIR/capture-stow.out" 2>"$TMP_DIR/capture-stow.err"
stow_failure_status=$?
set -e
[[ "$stow_failure_status" -eq 1 ]] || fail "Capture hid a Stow failure"
[[ "$(<"$source_path")" == rollback-source ]] || fail "Capture did not restore tracked source after Stow failure"
[[ ! -L "$live_path" && "$(<"$live_path")" == candidate ]] ||
  fail "Capture did not restore live source after Stow failure"

set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" STOW_CONCURRENT_TARGET="$live_path" \
  "$FIXTURE_ROOT/dotfiles" config capture fixture .config/fixture/divergent.txt \
  >"$TMP_DIR/capture-concurrent.out" 2>"$TMP_DIR/capture-concurrent.err"
concurrent_status=$?
set -e
[[ "$concurrent_status" -eq 1 ]] || fail "Capture hid a concurrent restore conflict"
[[ "$(<"$source_path")" == rollback-source ]] ||
  fail "Capture did not restore tracked source after a concurrent conflict"
[[ ! -L "$live_path" && "$(<"$live_path")" == 'concurrent state' ]] ||
  fail "Capture overwrote concurrent live state while restoring"
grep -F 'live restore was blocked' "$TMP_DIR/capture-concurrent.err" >/dev/null ||
  fail "Capture hid its concurrent restore conflict"
concurrent_backup="$(sed -n 's/^Backup: //p' "$TMP_DIR/capture-concurrent.err" | head -n 1)"
[[ -d "$concurrent_backup" ]] || fail "Capture did not preserve the conflicted safety backup"

set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  GITLEAKS_LOG="$gitleaks_log" STOW_CONCURRENT_TARGET="$live_path" \
  STOW_CONCURRENT_LINK="$TMP_DIR/concurrent-foreign-target" \
  "$FIXTURE_ROOT/dotfiles" config capture fixture .config/fixture/divergent.txt \
  >"$TMP_DIR/capture-concurrent-link.out" 2>"$TMP_DIR/capture-concurrent-link.err"
concurrent_link_status=$?
set -e
[[ "$concurrent_link_status" -eq 1 ]] || fail "Capture hid a concurrent symlink conflict"
[[ "$(<"$source_path")" == rollback-source ]] ||
  fail "Capture did not restore tracked source after a concurrent symlink"
[[ -L "$live_path" && "$(readlink "$live_path")" == "$TMP_DIR/concurrent-foreign-target" ]] ||
  fail "Capture overwrote a concurrent foreign symlink while restoring"
grep -F 'live restore was blocked' "$TMP_DIR/capture-concurrent-link.err" >/dev/null ||
  fail "Capture hid its concurrent symlink restore conflict"

backup_count_before="$(find "$data_home/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
set +e
PATH="$fake_bin:$PATH" HOME="$HOME_DIR" XDG_DATA_HOME="$data_home" \
  "$FIXTURE_ROOT/dotfiles" config resolve fixture .config/fixture/divergent.txt --agent claude \
  >"$TMP_DIR/resolve-nontty.out" 2>"$TMP_DIR/resolve-nontty.err"
resolve_nontty_status=$?
set -e
[[ "$resolve_nontty_status" -eq 1 ]] || fail "Resolve accepted a noninteractive invocation"
backup_count_after="$(find "$data_home/dotfiles/config-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$backup_count_after" == "$backup_count_before" ]] || fail "noninteractive Resolve created a backup"

[[ "$(stat -f '%Sp' "$data_home/dotfiles/config-backups")" == "drwx------" ]] ||
  fail "Config Lifecycle backup root is accessible to other users"

retention_data="$TMP_DIR/retention-data"
retention_root="$retention_data/dotfiles/config-backups"
mkdir -p "$retention_root" "$TMP_DIR/retention-foreign"
for backup_name in 20260101000000 20260201000000 20260301000000 20260401000000 20260501000000; do
  mkdir "$retention_root/$backup_name"
done
mkdir "$retention_root/manual-notes"
ln -s "$TMP_DIR/retention-foreign" "$retention_root/20200101000000"

retention_list="$(HOME="$HOME_DIR" XDG_DATA_HOME="$retention_data" \
  "$FIXTURE_ROOT/dotfiles" config backups list)"
[[ "$retention_list" == *"$retention_root/20260501000000"* ]] ||
  fail "Config Backup List omitted a retained backup"

retention_preview="$(HOME="$HOME_DIR" XDG_DATA_HOME="$retention_data" \
  "$FIXTURE_ROOT/dotfiles" config backups prune --keep 2)"
[[ "$(printf '%s\n' "$retention_preview" | grep -c '^Would prune ')" -eq 3 ]] ||
  fail "Config Backup Prune preview selected the wrong retention set"
[[ -d "$retention_root/20260101000000" ]] || fail "Config Backup Prune preview deleted data"

HOME="$HOME_DIR" XDG_DATA_HOME="$retention_data" \
  "$FIXTURE_ROOT/dotfiles" config backups prune --keep 2 --force \
  >"$TMP_DIR/retention-force.out"
[[ -d "$retention_root/20260501000000" && -d "$retention_root/20260401000000" ]] ||
  fail "Config Backup Prune removed a retained backup"
[[ ! -e "$retention_root/20260301000000" ]] || fail "Config Backup Prune kept an expired backup"
[[ -d "$retention_root/manual-notes" && -L "$retention_root/20200101000000" ]] ||
  fail "Config Backup Prune removed an unowned entry"

set +e
HOME="$HOME_DIR" XDG_DATA_HOME="$retention_data" \
  "$FIXTURE_ROOT/dotfiles" config backups prune --keep invalid \
  >"$TMP_DIR/retention-invalid.out" 2>"$TMP_DIR/retention-invalid.err"
retention_invalid_status=$?
set -e
[[ "$retention_invalid_status" -eq 2 ]] || fail "invalid backup retention did not return usage status"
