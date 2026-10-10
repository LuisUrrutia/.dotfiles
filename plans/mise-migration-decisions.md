# Mise migration: decision map

Status: core direction established; sync coverage awaits a user decision.
Updated: 2026-10-10.
Inspected repository: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`.

The authoritative implementation plan is [mise-migration.md](mise-migration.md).
The [inventory](mise-migration-inventory.md) records the existing scope.
These are tracked planning artifacts. No machine migration is authorized by
this planning request, and no package or live configuration was changed.

## Destination

Use mise to bootstrap fresh Macs and migrate Macs already using this repository.
Replace Stow and the Homebrew executable, preserve the installed capabilities,
and support configuration history and exchange between machines. Some machines
sync automatically; others exchange changes only on request. Preserve public,
reviewable setup code and machine records without publishing private state.

Success requires both a fresh installation and an existing-install migration
that work with `brew` and `stow` unavailable. Keeping `/opt/homebrew` as the
location of mise-managed bottles is compatible with that outcome; deleting the
prefix is not the objective.

The user chose mise and explicitly required complete Homebrew removal, including
existing installations. Preserving Homebrew indefinitely is not an alternative.
Unsupported recipes block the affected migration until an equivalent installation
route is verified; they do not silently remove a tool from scope.

## Decisions

| ID | Question | State | Depends on | Owner |
| --- | --- | --- | --- | --- |
| D1 | What must replace Homebrew? | Resolved by user | None | User |
| D2 | Where does shared history live, and who applies it? | Resolved direction | None | User; implementation for enrollment |
| D3 | How do native configuration modules fit the current repository? | Proposed design with an early proof gate | D1, D2 | Implementation |
| D4 | Which mechanism owns each configuration file? | Resolved policy | D2, D3 | Implementation |
| D5 | How do machine roles select Git identities? | Resolved model; enrollment inputs outstanding | D3, D4 | User supplies account/path data |
| D6 | What belongs in declarative macOS setup? | Resolved boundary | D1, D3 | Implementation |
| D7 | How are sensitive files recovered? | Proposed bounded design | D2, D4 | User supplies recipients at enrollment |
| D8 | Can existing package ownership transfer safely? | Open feasibility gate | D1 | Implementation |
| D9 | Which shared configuration edits use automatic history? | Waiting for user | D2 | User |

Dependencies are prerequisites. Version compatibility affects every implementation
unit and is verified first; it does not change the user's destination.

## D1: Remove the Homebrew executable

**Authority:** explicit user decision, including existing machines.

Keep existing mise runtimes and portable CLIs under `[tools]`. Use mise's native
`brew:` and `brew-cask:` bootstrap backends for suitable formulae, apps, and fonts.
Those backends install directly; the prefix name does not imply a dependency on
the `brew` command. Use `mas:` for App Store apps and `macos-app:` for verified
vendor app archives where appropriate.

This is a package-owner migration, not a blanket move of everything into
versioned `[tools]`. Native libraries, shell binaries, plugins, and apps have
different installation contracts. Existing editor-scoped ownership remains
unless a concrete compatibility issue requires changing it.

The formula backend currently excludes Intel macOS and implements only part of
the formula language. The current repo already assumes Apple Silicon in places.
Make macOS arm64 the tested initial platform; detect other architectures before
mutation and report them as unsupported, rather than silently skipping packages.
Adding Intel support requires a separate verified installation route.

**Would reopen:** evidence of an actively supported Intel target, or a package
that cannot be installed without Homebrew. The latter requires finding a
replacement route or a user decision about that capability, not keeping brew by
default.

Evidence: `brewfiles/`, `tools/mise/config/.config/mise/config.toml`;
https://mise.jdx.dev/bootstrap/packages/brew.html
https://mise.jdx.dev/bootstrap/packages/brew-cask.html

## D2: Public sources and private history

**Authority:** user selected per-machine manual and automatic synchronization
after the separate-private-history recommendation. The private repository's
name and the mode of each actual machine are enrollment inputs, not invented here.

Keep this Git repository authoritative for shared setup, templates, scripts, and
public machine records. Use a separate private mise history origin for explicitly
selected mutable configuration. Never attach mise history to this repository's
existing main branch: its history format and ancestry have different ownership.

Select `history.sync` locally: `manual` or `sync` per machine. Use `manual` until
a machine explicitly chooses automatic operation. Local autosave can run in both
modes. Git transport remains SSH. Automatic machines must prove authentication
works from the LaunchAgent environment, not just from an interactive shell.

Setup-code changes continue through Git review/commit/pull. Changes to selected
mutable files flow through mise history. D9 determines which shared configuration
sources also become mutable history-owned files. Do not give Git and mise history
independent write authority over the same checkout files. A regular mutable file
must not also be overwritten by a stale copy entry on the next bootstrap.

`mise dot sync` exchanges checkpoints; `mise dot pull` applies them. Applying
history does not install packages or render templates. Setup changes require a
separate bootstrap. Automatic sync must not become automatic execution of newly
received setup code.

**Alternatives:** Git alone loses the requested native history exchange. A single
automatic public history store risks publishing app state and bypassing review.
An automatic private store on every machine conflicts with the user's choice.

Evidence:
https://mise.jdx.dev/dotfiles/sync.html
https://mise.jdx.dev/dotfiles/history.html
https://mise.jdx.dev/bootstrap/from-repository.html

## D3: Keep sources; use native modules

**Proposed direction:** preserve `tools/<tool>/config` during migration. Add a
root bootstrap project, `mise.toml` plus `mise.<profile>.toml` environments.
Keep globally available runtimes and history policy in the existing global mise
configuration tree, extended with native `conf.d` fragments where needed.
Machine enrollment selects native environments through `miserc.local.toml`.

The root project owns machine provisioning. Global config owns tools that must
resolve outside the checkout and history settings that mise does not accept from
project config. Each declaration has one authoritative file. Do not duplicate
runtime lists in root and global config, or invent a second module interpreter.

A small Bash 3.2 entrypoint installs the official mise binary, prepares access
and safe global-config enrollment, then runs the project bootstrap. It must load
the new global config before resolving tools in that same process sequence.
`--from` is the repository bootstrap path once prerequisites are satisfied;
`--adopt` is reserved for the separate history origin. Validate first-use behavior
before promising that bare `--from` replaces the fresh-Mac entrypoint.

**Alternative considered:** restructure the public repo as a global config
checkout with `--adopt`. This is viable upstream, but changes the checkout layout
and entangles the public checkout with later private-history adoption. Keeping
the project at `~/.dotfiles` preserves existing consumers and isolates the two
repositories. Moving all source files is not needed to replace Stow.

**Proof gate:** test first-run global enrollment, global/project precedence,
module selection, watcher visibility, and no duplicate hooks. An isolated probe
on mise 2026.10.1 confirmed global config symlinks, a local environment selection,
and `conf.d` load together. It did not prove the full first-use bootstrap.

Evidence: `tools/mise/install.sh`, `tools/lib.sh`, `bootstrap/profiles.sh`;
https://mise.jdx.dev/bootstrap/modules.html
https://mise.jdx.dev/bootstrap/from-repository.html

## D4: Explicit file ownership and preservation

Use per-tool `symlink-each` groups for shared source files, with a Git manifest
and translated Stow exclusions. Prefer regular live directories so application
state never lands in the public checkout. Use whole-directory symlinks only when
the entire directory is intentionally source-owned.

Use templates for generated machine values; structured merge edits for owned
keys in app-written TOML/JSON/YAML; blocks or lines for compatible startup files;
tracking for files whose live contents are authoritative. A copy is deployment,
not bidirectional synchronization. Seed a mutable tracked file only when absent,
then stop declaring a copy owner for it. Capture public changes explicitly.

Do not use `absent` as general cleanup: its declaration authorizes removing a
regular file without proving ownership. Use it only for a reviewed retired path
after preservation and migration checks. Never use blanket force/prune flags.

Keep the existing conflict preflight and capture/discard decision boundary.
Native mise semantics alone are insufficient: a scratch probe on 2026.10.1
confirmed that apply repoints a foreign symlink and overwrites an edited copy
without force. The foreign source itself survived. All probe paths were in an
isolated temporary HOME/XDG tree.

Apply the guard at supported mutating entrypoints, including a root pre-dotfiles
hook. Test direct `mise dot apply` separately: bootstrap hooks cannot be assumed
to protect that command. Until an equivalent guard exists there, document it as
a lower-level command and expose safe mutation through `dotfiles config`.

Evidence: `config/run.sh`, `config/tests/lifecycle.sh`, `tools/lib.sh`;
https://mise.jdx.dev/dotfiles/managed.html
https://mise.jdx.dev/dotfiles/groups.html
https://mise.jdx.dev/dotfiles/edits.html

## D5: Machine identities and directory scopes

Keep tracked hardware records in `machines/` and preserve the existing
`DOTFILES_HARDWARE_*`, `DOTFILES_GIT_*`, and `DOTFILES_MANAGED_GIT_*` compatibility
until callers migrate. Enrollment produces native local mise selection/data;
generated local files are not a second hand-maintained authority.

The logical record contains the default Git identity and an ordered list of
directory-scoped identity overrides. Each identity can carry name, email, public
signing-key reference, and signing-program path. Selection is separate from the
role label: do not equate a hostname with an account or infer emails.

Cover these user-specified cases:

- Personal: one default identity.
- Work: two identities selected by directory; determine the fallback explicitly.
- Agent machine: one global identity and another for selected directories.

Keep `~/.config/git/local.gitconfig` identity-free. Prefer templates for a
dedicated generated machine include and its scoped includes, preserving unrelated
keys and includes in `~/.gitconfig`. Keep its canonical shared include first.
Use Git `includeIf` directory rules and verify worktree resolution. Commit identity
does not select SSH authentication; test host aliases/keys and gh actor selection
independently.

**Outstanding input:** actual account-to-directory mappings and private-history
origin at enrollment. The schema and synthetic tests can be implemented without
those values. Existing unknown-machine identity fallbacks remain supported.

Evidence: `tools/git/common.sh`, `tools/git/migrate-config.sh`,
`tools/git/tests/identity.sh`, `machines/55930b1d4d8e.sh`;
https://mise.jdx.dev/dotfiles/managed.html

## D6: Declarative macOS setup has a boundary

Move supported user preferences into named macOS settings or raw defaults.
Use explicit current-host entries and dictionary paths where needed. Preserve
types and unrelated dictionary keys. Use native LaunchAgents for the appearance
schedule, with an explicit handoff from its old label to `dev.mise.*`.

System preferences, hostname changes, power policy, FileVault, screen-lock
authentication, file associations, and other commands outside the native schema
remain small idempotent mise tasks. Do not force these into user defaults.
Keep unsupported plist behavior in a dedicated task until equivalent behavior is
proved. Read `tools/hammerspoon/AGENTS.md` before changing screen-lock behavior.

Fish comes from `brew:fish`, with a stable absolute login-shell path. Mise can
register and select it. Retain exactly one activation owner: the current early
Fish `conf.d` activation has ordering dependencies that must be tested before
replacing it with native `fish = "auto"` activation in `config.fish`.

Official mise goes in `~/.local/bin`; initial setup works from stock zsh or Bash
without Fish or Homebrew. Native system installs are for tools genuinely shared
across users, not a synonym for packages that need privileged installation.

Evidence: `tools/macos/install.sh`, `tools/fish/install.sh`,
`tools/fish/config/.config/fish/conf.d/02_mise.fish`;
https://mise.jdx.dev/bootstrap/macos-defaults.html
https://mise.jdx.dev/bootstrap/launchd.html
https://mise.jdx.dev/bootstrap/shell.html
https://mise.jdx.dev/dev-tools/system-installs.html

## D7: Encryption and recovery

Provide opt-in age encryption for selected private-history files before their
first save. Keep credentials sourced through 1Password/2password where possible;
do not turn application sessions, auth databases, or entire home directories into
sync payloads. Public setup contains references and public keys only.

Use independent age identities per enrolled machine plus an offline/recoverable
recipient. Keep private identities out of tracking; store recovery material in
the password manager through its documented secure input flow. Test restoration
with dummy secrets before enrolling real files.

Native machine variants cannot currently be combined with encryption, and
track-local does not accept it either. Do not promise that combination. Use
track-local for strictly local files, or separate encrypted paths with a verified
selection design if an actual private per-machine sharing requirement arises.

**Limits:** encryption does not hide filenames or remove old plaintext history.
Hardware/plugin recipients cannot be assumed to work from a background watcher.
Key distribution and the private origin must be ready before enabling automatic
sharing; a missing key must never fall back to plaintext.

Evidence:
https://mise.jdx.dev/dotfiles/encryption.html
https://mise.jdx.dev/dotfiles/history.html

## D8: Existing cask ownership is the critical feasibility gate

Mise detects Homebrew-owned casks but does not upgrade them as mise-owned casks.
Therefore importing declarations and observing "installed" does not prove a
completed migration. Generic `adopt = true` is not proof of receipt conversion.

Build and test an explicit ownership-transfer procedure before touching live
apps. Compare supported metadata handoff, vendor-managed self-updates with a
declared installation owner, and controlled reinstall when necessary. Do not edit
receipts speculatively or run an uninstaller that removes shared dependencies.
Any destructive per-app step needs a concrete reviewed action at execution time.

First test self-updating screen-recording apps, third-party taps, pkg installers,
drivers, and extensions. Privacy grants require a GUI check; neither a dry run
nor successful installation proves they survived. The project must not claim
that mise grants or universally preserves macOS TCC permissions.

**Gate:** every installed in-scope package has a verified install/update owner
without brew. If a recipe fails, test the upstream binary, vendor package, or a
small declarative package plugin. Replacing the app itself requires a user choice.

Evidence: current Brewfiles;
https://mise.jdx.dev/bootstrap/packages/brew-cask.html
https://mise.jdx.dev/bootstrap/packages/macos-app.html

## Continuation

The independent feasibility work is ready. Resolve D9 before finalizing shared
configuration deployment and history enrollment. Production cutover also requires
the compatibility results, per-machine enrollment data, and fresh/existing Mac
acceptance. These are delivery gates, not claims that migration already works.

## D9: Automatic synchronization coverage

**Question pending:** on automatic machines, should edits to selected shared
configuration such as Fish, editor settings, and Starship travel through native
mise history, or only app-written files while source-backed configuration still
travels through Git?

**Recommendation:** include selected shared configuration in native history, with
public publication as an explicit reviewed promotion. This most directly serves
the user's cross-machine editing goal. Setup code, package manifests, generated
machine identities, secrets, and runtime data remain outside that shared stream.

This changes D4's per-file ownership classification. History-owned files must be
regular live files or point into history-owned sources outside the public checkout.
Public sources become reviewed seeds; bootstrap must not overwrite newer live
history with an older seed. Moving reviewed changes in either direction needs
explicit capture/reconciliation, not an unconditional copy on every apply.

The narrower alternative keeps ordinary shared sources symlinked into this repo;
it is simpler, but those edits do not automatically propagate through mise.
M0-M4 can progress under either answer. Final M5/M10 contracts depend on the answer.
