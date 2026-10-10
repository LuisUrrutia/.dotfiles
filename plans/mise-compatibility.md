# Mise compatibility and implementation evidence

Tested on 2026-10-10, macOS arm64, with the official **2026.10.7** binary.
The operator's mise 2026.10.1 and existing installation were left unchanged.

The initial 2026.10.3 probe passed basic composition and history checks but
silently treated a `merge = true` declaration as a whole-file target. Version
2026.10.7 correctly applies structured edits and is the minimum supported
version. This is a necessary exception to the usual three-day release cooldown;
ordinary tool and self-update policy retains that cooldown.

Release: https://github.com/jdx/mise/releases/tag/v2026.10.7

Pinned official release SHA-256 values:

- macOS arm64: `5841e5ab5009b4c4dd2b641ddbfc6777cc1b9c9c0ffd375001e294540e9e9cc8`
- macOS x64: `809b60fb1f7f5b8794db9c2ac78e5dc40df2e2a2e91d75e7dc97da1ecdc2755e`

Full setup is accepted only for arm64. The small binary installer also recognizes
macOS x64; that does not establish x64 package/setup acceptance.

## Observed native contracts

Experiments use temporary HOME/config/data/cache/state directories, synthetic
preferences and SSH encryption keys, and local bare Git origins. They run the
actual release binary and Git, without installing machine packages or services.

- Global `conf.d/<tool>/mise.toml` composes with `config.toml`. `auto_env = true`
  selects the macOS fragment; local environments select individual optional apps.
- Relative file sources resolve within their module. `symlink-each` keeps real
  target directories and deploys only the selected application files.
- Tracking the active tree saves manifests, sources and tasks. Explicit exclusions
  keep machine-local configuration and private snapshots out of its plaintext rule.
- A separate encrypted subtree produces ciphertext on its first history save.
  Adoption without a matching identity fails; supplying the synthetic key restores
  the bytes while preserving the other client's local identity/app selections.
- The actual enrollment command can adopt history with every setup phase skipped;
  `--seed-only` restores source files without creating their live application links.
- Save/sync/pull exchanges managed sources and declarations. Automatic application
  runs a newly received setup task and leaves an unselected app undeployed.
- Concurrent edits preserve the local file. **Native sync can return zero with
  conflicts**; status JSON and pull must also be checked before application.
- Structured merge preserves unrelated keys but does not track its output. The
  repository captures changed owned keys into the shared source before exchange;
  unrelated project/plugin keys stay local. Both-side edits require a decision.
- `config --json` lists loaded files from highest precedence to lowest.
  `config get` reads one stored file, not the merged effective configuration.
- `bootstrap plan --json` is not a complete dotfile/resource inventory. Resource
  status commands can warn and skip invalid entries while returning zero; the
  application gate rejects those warnings and checks required missing resources.
- In 2026.10.7, saving a checkpoint before any encrypted file exists loses
  the stored recipients; a later first encrypted save fails. Enrollment seeds a
  small encrypted `.encryption-policy` file before any checkpoint. The regression
  covers initial application with no app snapshots followed by the first snapshot.
- `dot save --re-encrypt` is present in 2026.10.7. The old 2026.10.3 limitation is
  no longer applicable. Rotation still requires a separate recovery exercise.

The official 2026.10.7 package driver processes managers sequentially and checks
availability when each manager runs. The retained `brew:mas` route and package
PATH provide the App Store CLI; real App Store authentication/install remains
part of fresh-Mac acceptance. Source:
https://github.com/jdx/mise/blob/v2026.10.7/src/system/driver.rs

## Repository checks

`mise run verify` is the maintained entry point. It covers:

- Python compilation; TOML/JSON/JSONC/YAML/JavaScript parsing; EditorConfig;
  Bash 3.2/ShellCheck; Fish syntax; Lua/Neovim formatting; Claude settings schema;
  Git config parsing; actionlint and pinned GitHub actions; secret scanning.
- Four integration areas: safe native deployment and partial-key capture;
  personal/work/agent/unknown Git identities including Worktrunk worktrees;
  encrypted preference recovery; native manual/automatic two-client exchange.
- Regression cases for source changes during bootstrap, cancellation of timed-out
  descendants, warning-based resource skips, preference resets, invalid app-file
  structure, pending restore, and fresh same-machine LinearMouse recovery.
- A noninteractive Fish smoke path and `install.sh --dry-run`.
- Staged and unstaged `git diff --check`.

The local run uses the pinned binary, isolated mise directories, and already
available verification tools. It does not provision the operator's machine.
CI provisions its tools with mise on a disposable `macos-26` runner after moving
aside the runner's preinstalled Homebrew prefix. No hosted workflow was dispatched.

Final execution on 2026-10-10: `/bin/bash
.tmp/mise-implementation/verify-entrypoint.sh` invoked `mise run verify` and exited
with status **0**. All four integration tests passed in **254.790 seconds**;
the parser/static, smoke, secret-scan and diff checks also passed. The wrapper and
`verify-final.log` are local ignored evidence under `.tmp/mise-implementation/`,
not required files in a fresh checkout. The maintained command is `mise run verify`.

Additional isolated probes verified the official installer downloading the pinned
release, preserving an older executable, a stable rerun, refusal of a regular
non-executable destination, checksum failure without replacement, and refusal
of a redirected parent. Native retry probes confirmed three failed executions
then a stopped automatic retry; the test advances the local backoff clock rather
than waiting through all intervals. An unavailable local origin stops before
application. An unchanged task with `sources` runs only once across two bootstraps.

The package ownership audit compares the retained baseline with the native module
tables: **162 package declarations, 25 retained mise tools, no missing retained
entry, no duplicate owner, and unchanged retained tool version requests**. Aliases
are canonicalized (`cpanm` → `cpanminus`, `pkg-config` → `pkgconf`, `libvips` → `vips`).
Per-package fresh-install/update results remain explicitly pending in
[mise-package-coverage.tsv](mise-package-coverage.tsv).

## Preference format evidence

A read-only local inspection recorded field names/types and file-format version
numbers for Thaw 2.0.1, LinearMouse 0.12.0, SuperCmd 1.0.9, SoundSource 6.1.4,
Loopback 2.5.0 and Audio Hijack 4.6.0. Read-only validation of the existing exports
and companion files passed for all six definitions. It did not copy private values into this repository or create a
preference backup.

Definitions validate owned CFPreferences types and companion root fields/version
headers. Apple `plutil` normalizes exported plist data before parsing because
SuperCmd's export can contain characters a strict XML parser rejects. Captured
plists are binary, then encrypted by native history. These structural checks do
not prove every opaque app field or actual reopen behavior.

## Outstanding acceptance

The repository implementation is ready for the separate fresh-Mac exercise in
[POST_INSTALL.md](../POST_INSTALL.md). This environment cannot establish:

- Installation/update of every native formula, cask, driver, tap or App Store app
  without Homebrew; same-run plugin/runtime behavior and receipt recovery.
- Full Disk Access, sudo, login-shell registration, launchd services, privileged
  defaults and system settings on a newly installed Mac.
- Real capture/restore/reopen for all six apps, hardware routing and sessions,
  helper-process consistency, and recovery with a separately held age key.
- Cask self-update and macOS privacy behavior after an actual app replacement.
- Hosted CI execution, Ubuntu/Arch setup, or a non-arm64 full installation.

An isolated package dry-run still sees the operator's existing prefix and failed
on an old ChatGPT Caskroom receipt. That is not fresh-install evidence; the prefix
was not repaired or changed. Self-updating casks reduce replacement, but replacement
can still reset privacy grants:
https://mise.jdx.dev/bootstrap/packages/brew-cask.html#macos-privacy-permissions

No live preferences were backed up, private origin created, credentials enrolled,
or machine setup performed. Keep wanted old settings independently before erase.

References:

- https://mise.jdx.dev/bootstrap/modules.html
- https://mise.jdx.dev/dotfiles/managed.html
- https://mise.jdx.dev/dotfiles/edits.html
- https://mise.jdx.dev/dotfiles/history.html
- https://mise.jdx.dev/dotfiles/encryption.html
- https://mise.jdx.dev/dotfiles/sync.html
