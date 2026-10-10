# Mise migration: decision map

Status: direction established, including full setup synchronization; feasibility
gates remain before implementation.
Updated: 2026-10-10.
Inspected repository: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`.

The authoritative implementation plan is [mise-migration.md](mise-migration.md).
The [inventory](mise-migration-inventory.md) records the existing scope.
These are tracked planning artifacts. No machine migration is authorized by
this planning request, and no package or live configuration was changed.

## Destination

Use mise to bootstrap fresh Macs and migrate Macs already using this repository.
Replace Stow and the Homebrew executable, preserve the installed capabilities,
and support configuration and software-declaration exchange between machines.
Automatic machines receive and apply setup changes for their selected profiles;
manual machines exchange and apply them on request. Preserve a public, reviewable
baseline and machine records without publishing private operational state.

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
| D2 | Where does shared history live, and who applies it? | Resolved direction | D9 | User; implementation for enrollment |
| D3 | What structure follows mise rather than Stow? | Revised proposal; native module probe passed | D1, D2 | User direction; implementation design |
| D4 | Which mechanism owns each configuration file? | Resolved policy | D2, D3 | Implementation |
| D5 | How do machine roles select Git identities? | Resolved model; enrollment inputs outstanding | D3, D4 | User supplies account/path data |
| D6 | What belongs in declarative macOS setup? | Resolved boundary | D1, D3 | Implementation |
| D7 | How are sensitive files recovered? | Proposed bounded design | D2, D4 | User supplies recipients at enrollment |
| D8 | Can existing package ownership transfer safely? | Open feasibility gate | D1 | Implementation |
| D9 | Does sync include shared configuration and installed software? | Resolved by user | None | User |
| D10 | How are received software/setup changes applied? | Proposed serial application cycle | D2, D3, D4 | Implementation |

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

## D2: Public baseline and private operational history

**Authority:** the user selected per-machine manual and automatic synchronization,
then included all managed configuration and software changes in D9. The private
repository's name and each machine's mode are enrollment inputs.

Keep this public Git repository as the shareable baseline, implementation/test
source, and destination for reviewed publication. The separate private mise
history origin owns the enrolled user's effective setup: declarations, supporting
sources/tasks, and managed mutable configuration. Never attach mise history to
the public repository's existing main branch or give both independent write
ownership over the public checkout.

Public files seed a first enrollment. Later public imports and private-to-public
promotion use explicit diff/merge and secret review. Repeating bootstrap must not
reset private edits from an older public seed. This replaces the initial plan's
split in which setup code traveled only through public Git.

Machine mode and origin remain local. Manual machines save locally and exchange
or apply only on request. Automatic machines exchange and apply complete setup
changes through D10, including newly received setup tasks. Git transport remains
SSH; prove authentication from the LaunchAgent environment.

Native `mise dot sync` exchanges checkpoints and `mise dot pull` restores files.
Neither installs packages nor renders templates. Full automatic setup therefore
requires a separate application cycle, not just native `history.sync = "sync"`.

**Alternatives:** public Git alone does not provide the requested private history
exchange. Publishing operational history to the public repo exposes private state.
Automatic operation on every machine contradicts the per-machine choice.

Evidence:
https://mise.jdx.dev/dotfiles/sync.html
https://mise.jdx.dev/dotfiles/history.html
https://mise.jdx.dev/bootstrap/from-repository.html

## D3: A native mise tree with cohesive modules

**Authority:** the user rejected retaining Stow-shaped paths and requested a new
structure designed around mise. Preserve capabilities and public machine records,
not the old `tools/<tool>/config/.config/<tool>` layout.

**Proposed direction:** the public root contains `config.toml`, `conf.d/`, and
`tasks/`, matching mise's global configuration layout. Each `conf.d/<capability>/`
keeps its declarations, config sources, templates, and necessary scripts together.
For example, `conf.d/fish/mise.toml` sits beside `config.fish`, `fish_plugins`,
`conf.d/`, `functions/`, and `completions/`. The inner `conf.d` is Fish's real
configuration structure. No synthetic HOME tree or extra `config/` wrapper is
needed. A one-file module can keep its source beside its manifest too.

A module's `mise.toml` holds all its common packages, managed paths, native host
settings/services, and task definitions. Use `mise.<profile>.toml` in that same
module for optional declarations. Selecting `dev` loads matching module fragments;
it does not require a separate hand-maintained module index. Keep optional-only
resources out of the always-loaded file. Native `config.<profile>.toml` remains
available for a real setup-wide override, not a duplicate package list.

The public distribution also needs `install.sh` and a small `bootstrap/` for
first-use/migration, `machines/` for public enrollment records, `tests/` for
verification, and the existing planning/docs. Root `mise.toml` owns repository
verification and the enrollment adapter, not a second machine package/config
manifest. Ordinary setup behavior belongs in native declarations or module tasks;
shared operational commands belong in native `tasks/`. Keep `dotfiles` only as a
thin compatibility command over that route, not another implementation tree.

Enroll `config.toml`, `conf.d/`, `tasks/`, and any actual global environment files
as regular files under `~/.config/mise`, preserving their relative structure.
This single active tree owns both mise configuration and its supporting sources.
There is no separate `~/.local/share/dotfiles/setup/` source mirror. Track its shared
contents in private history; `miserc.local.toml`, `config.local.toml`, credentials,
and runtime state remain local or use their explicit history policy.

Keep the public checkout separate. Initial public enrollment seeds only the
allowlisted native payload, without copying `.git`, tests, or repository tooling.
Do not adopt the public checkout into the active directory and then attach a
different private history origin: native setup adoption checks existing checkout
origins. Later machines can adopt the private setup directly. Public imports and
promotion still use D2's explicit diff/merge. Normal bootstrap runs from a neutral
working directory so repository tooling cannot override the active configuration.

**Alternatives:** retaining Stow's layout reduces moves but preserves artificial
path nesting and separates each tool's behavior across old installer layers.
A flat `dotfiles/` tree plus a large central manifest shortens paths but separates
sources from packages, templates, and services that change together. Native
`conf.d` folders give that cohesion without a custom module loader.

This supersedes the previous proposal to retain public tool paths and maintain a
separate active source workspace. The previous root-project/global split was
already superseded by D9's full setup sync requirement.

**Evidence and proof limits:** an isolated 2026.10.1 probe loaded a common module,
selected a folder-local `mise.dev.toml` through `miserc.local.toml`, applied
relative sources with per-file links into real directories, omitted the module
manifest from deployment, and ran a global file task. No live paths or packages
changed. M0 must still prove complete enrollment/adoption, history coverage,
package/service behavior, and the selected release's full bootstrap ordering.

Evidence: the inventory's module-layout probe;
https://mise.jdx.dev/bootstrap/modules.html
https://mise.jdx.dev/bootstrap/from-repository.html
https://mise.jdx.dev/dotfiles/managed.html

## D4: Explicit file ownership and preservation

Use module-local `[dotfiles]` entries with explicit destinations and sources
relative to the declaring manifest. Link individual files and use `symlink-each`
for application-owned subdirectories such as Fish functions. Module manifests,
tasks, templates, and tests must not leak into live app config through a recursive
link of the entire module. Use native groups when an actual source tree shares a
target/mode; do not recreate a HOME-shaped tree just to give every tool a group.

Use explicit source membership and translated Stow exclusions. A Git manifest can
verify public seed membership; it cannot enumerate the regular active tree
without a Git index. Track source contents as well as relevant managed links.
Prefer regular live directories so runtime data stays outside source files. Use
whole-directory links only when the complete directory is intentionally managed.

Use templates for generated machine values; structured merge edits for owned
keys in app-written TOML/JSON/YAML; blocks or lines for compatible startup files;
tracking for files whose live contents are authoritative. Their shared inputs
also belong to private history. A copy is deployment, not bidirectional sync.
Seed a mutable tracked file only when absent, then stop declaring a copy owner
for it. Keep generated machine outputs local or correctly scoped; synchronize
their shared inputs. Publish changes to the public baseline explicitly.

Do not use `absent` as general cleanup: its declaration authorizes removing a
regular file without proving ownership. Use it only for a reviewed retired path
after preservation and migration checks. Never use blanket force/prune flags.

Keep the existing conflict preflight and capture/discard decision boundary.
Native mise semantics alone are insufficient: a scratch probe on 2026.10.1
confirmed that apply repoints a foreign symlink and overwrites an edited copy
without force. The foreign source itself survived. All probe paths were in an
isolated temporary HOME/XDG tree.

Apply the guard at supported mutating entrypoints, including the effective setup
pre-dotfiles hook. Test direct `mise dot apply` separately: bootstrap hooks cannot
be assumed to protect that command. Until an equivalent guard exists there,
document it as a lower-level command and expose safe mutation through
`dotfiles config`.

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

## D9: Synchronize the complete managed setup

**Authority:** the user confirmed all changes, including what gets installed,
when asked whether Fish, editor, and Starship changes should travel automatically.

Include all managed shared configuration, package/tool declarations, plugin
manifests, templates, and required setup code in private history. Apply shared
changes on every enrolled machine and profile-scoped changes only on matching
machines. Preserve distinct machine roles, identities, local choices, and the
existing secret/runtime exclusions. "All" describes managed setup, not every file
or installed binary on a Mac.

The supported software-add workflow must record a declaration and its scope
before installation, so another machine can reproduce it. Sync the installation
intent and version policy; download artifacts locally. An installation outside
that workflow needs inventory and enrollment before it can propagate. Do not
claim that mise history automatically discovers arbitrary installers.

Manual machines retain explicit exchange/application. On automatic machines,
receiving a valid complete setup revision includes applying its packages and
setup tasks through D10. This supersedes the earlier recommendation to exclude
setup code and package manifests from automatic history. It does not authorize
running this migration during the planning task.

## D10: Serialize exchange and setup application

**Proposed direction:** one application command owns save/sync/pull and conditional
bootstrap, with a native LaunchAgent scheduling it only on automatic machines.
Use native history for checkpoints, exchange, conflict resolution, and recovery;
do not implement a second Git synchronization engine.

Keep native `history.sync = "manual"` on both modes while the native watcher
performs local autosaves. The scheduled command provides full automatic exchange
and application; manual machines invoke it on request. This avoids a second
background writer applying incoming files during bootstrap. Machine mode is a
local enrollment setting, not the name of mise's native sync setting.

The command serializes supported mutations, waits for settled and valid inputs,
checks for conflicts or incomplete recovery, exchanges and restores the complete
revision, then applies the effective local profile. Recheck state before setup;
record success only after required package/config/service checks pass. Use a
setup-input fingerprint plus local selection to avoid bootstrap loops caused by
its own checkpoints. Retry failures with bounded backoff and expose pending,
failed, and applied state. Prove the protocol in M0 before relying on it.

Do not invoke bootstrap synchronously from `[history.reload]`; upstream reserves
those hooks for reloading applications, and nested setup may contend on locks.
Serialize the scheduled path with manual operations and ordinary software setup.
Raw native commands retain their lower-level semantics.

Automatic mode permits received setup code to execute as the enrolled user.
Retain noninteractive failure behavior: missing sudo, App Store authentication,
or macOS permission steps become visible prerequisites, not prompts or success.
Never grant privileges as a side effect. Removing a declaration does not authorize
blanket package pruning or deletion of unknown files; report destructive cleanup
for explicit handling under the existing preservation contract.

Evidence:
https://mise.jdx.dev/dotfiles/sync.html
https://mise.jdx.dev/dotfiles/history.html
https://mise.jdx.dev/bootstrap.html

## Continuation

No sync-coverage decision remains open. M0 verifies global setup composition,
package ownership transfer, and the serial exchange/application protocol before
implementation depends on them. Actual origin, machine modes, identities, and
key references are enrollment inputs. Production cutover still requires those
proofs and fresh/existing Mac acceptance.
