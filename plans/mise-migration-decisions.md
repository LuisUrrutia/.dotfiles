# Mise-native setup: decision map

Status: direction established, including full setup synchronization, a common
base with app exceptions, encrypted app preferences, and a smaller test suite.
The user chose a fresh macOS install; existing-install migration is cancelled.
macOS is the first delivery; D14 preserves a path to a future Ubuntu/Arch mini PC.
Fresh-setup feasibility gates remain before implementation.
Updated: 2026-10-10.
Inspected repository: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`.

The authoritative implementation plan is [mise-migration.md](mise-migration.md).
The [inventory](mise-migration-inventory.md) records the existing scope.
These are tracked planning artifacts. No disk erase or machine setup is authorized
by this planning request, and no package or live configuration was changed.

## Destination

Use mise to bootstrap fresh Macs after the user reinstalls macOS. Rebuild the
repository without Stow or the Homebrew executable, preserve retained capabilities,
and support configuration and software-declaration exchange between machines.
Automatic machines receive and apply common setup and enabled-app changes;
manual machines exchange and apply them on request. Preserve a public, reviewable
baseline and machine records without publishing private operational state.
Keep shared configuration and synchronization portable; macOS-specific resources
must be isolated for the future Linux extension. Linux support is not delivered
or verified by this plan's initial macOS acceptance.

Success requires fresh installation, repeat bootstrap, and updates with `brew`
and `stow` absent. Mise-managed bottles may use `/opt/homebrew`; the directory
name does not imply the Homebrew executable is installed.

The user chose mise and a setup without Homebrew, then explicitly cancelled
existing-install migration in D13. Unsupported required recipes still need a
verified installation route; they do not silently remove a retained tool.

## Decisions

| ID | Question | State | Depends on | Owner |
| --- | --- | --- | --- | --- |
| D1 | How does the fresh setup avoid Homebrew? | Resolved by user | D13 | User |
| D2 | Where does shared history live, and who applies it? | Resolved direction | D9 | User; implementation for enrollment |
| D3 | What structure follows mise rather than Stow? | Revised proposal; native module probe passed | D1, D2 | User direction; implementation design |
| D4 | Which mechanism owns each configuration file? | Resolved policy | D2, D3 | Implementation |
| D5 | How do machine roles select Git identities? | Resolved model; enrollment inputs outstanding | D3, D4 | User supplies account/path data |
| D6 | What belongs in declarative macOS setup? | Resolved boundary | D1, D3 | Implementation |
| D7 | How are private app preferences captured and recovered? | Mandatory encryption; proposed restore boundary | D2, D4 | User scope; implementation; recipients at enrollment |
| D8 | Is existing package ownership transfer required? | Closed: out of scope | D13 | User |
| D9 | Does sync include shared configuration and installed software? | Resolved by user | None | User |
| D10 | How are received software/setup changes applied? | Proposed serial application cycle | D2, D3, D4 | Implementation |
| D11 | What is common, optional, or retired? | Resolved by user; individual app enrollment remains | None | User |
| D12 | Which tests deserve to survive the rebuild? | Resolved policy | Retained behavior | User direction; implementation |
| D13 | Does delivery support existing Macs or only fresh setup? | Fresh setup only; migration cancelled | None | User |
| D14 | How can Ubuntu or Arch be added later? | Portability required now; Linux delivery deferred | D3, D9, D13 | User direction; implementation boundaries |

Dependencies are prerequisites. Version compatibility affects every implementation
unit and is verified first; it does not change the user's destination.

## D1: Install without the Homebrew executable

**Authority:** the user requires no Homebrew executable. D13 narrows the
installation target to fresh macOS and removes uninstall/transfer work.

Keep existing mise runtimes and portable CLIs under `[tools]`. Use mise's native
`brew:` and `brew-cask:` bootstrap backends for suitable formulae, apps, and fonts.
Those backends install directly; the prefix name does not imply a dependency on
the `brew` command. Use `mas:` for App Store apps and `macos-app:` for verified
vendor app archives where appropriate.

Choose the manager by capability rather than moving everything into versioned
`[tools]`. Native libraries, shell binaries, plugins, and apps have
different installation contracts. Existing editor-scoped ownership remains
unless a concrete compatibility issue requires changing it.

The formula backend currently excludes Intel macOS and implements only part of
the formula language. The current repo already assumes Apple Silicon in places.
Make macOS arm64 the tested initial platform; detect other architectures before
mutation and report them as unsupported, rather than silently skipping packages.
Adding Intel macOS support requires a separate verified installation route;
this restriction does not rule out a future Linux x64 mini PC under D14.

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

**Proposed direction:** the public root contains `config.toml`, `miserc.toml`,
`conf.d/`, and `tasks/`, matching mise's global configuration layout.
Each `conf.d/<capability>/` keeps declarations, config sources, templates, and
necessary scripts together.
For example, `conf.d/fish/mise.toml` sits beside `config.fish`, `fish_plugins`,
`conf.d/`, `functions/`, and `completions/`. The inner `conf.d` is Fish's real
configuration structure. No synthetic HOME tree or extra `config/` wrapper is
needed. A one-file module can keep its source beside its manifest too.

A module's `mise.toml` holds portable declarations and tasks. Platform fragments
such as `mise.macos.toml` hold the OS-specific parts under D14. D11 removes the
old installation profiles: cloud, development, formatting, image, and language
capabilities belong to every Mac's base, with platform eligibility preserved.
Use `mise.<app>.toml` for an individual optional capability, such as Loopback or
DisplayLink. Local `env = ["loopback"]` activates that module using mise's native
mechanism. Keep its packages, files, and services under the same selection. No
profile menu, role preset, alias system, or duplicate module index is needed.

The public distribution also needs `install.sh` and a small `bootstrap/` for
first-use enrollment, `machines/` for public enrollment records, `tests/` for
verification, and the existing planning/docs. Root `mise.toml` owns repository
verification and the enrollment adapter, not a second machine package/config
manifest. Ordinary setup behavior belongs in native declarations or module tasks;
shared operational commands belong in native `tasks/`. Any retained `dotfiles`
command is a thin convenience wrapper. Legacy CLI grammar, profile selectors,
and old-state converters are not compatibility requirements.

Enroll `config.toml`, `miserc.toml`, `conf.d/`, `tasks/`, and global environment
files as regular files under `~/.config/mise`, preserving their relative structure.
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
after preservation and ownership checks. Never use blanket force/prune flags.

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

Keep public hardware and identity records tracked in `machines/`; express their
retained values in the new native enrollment schema. D13 removes the need for
legacy `DOTFILES_*` interfaces or a converter for the former installed Git layout.
Enrollment produces local mise selection/data; generated local files are not a
second hand-maintained authority.

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
schedule using `dev.mise.*` labels. Fresh setup needs no old-service handoff.

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

**Authority:** the user requires all backed-up plists to be encrypted and adds
Thaw, LinearMouse, SuperCmd, SoundSource, Loopback, and Audio Hijack settings to
scope. Encryption is mandatory for those preference backups, not an opt-in.

Configure native age encryption before the first checkpoint of any captured
plist, including companion private config files. Public modules contain package
declarations, capture/restore policy, and necessary adapters. Actual preferences
belong in private encrypted history. Live files and export staging remain
readable locally; encryption protects stored versions, not running applications.

Prefer native tracking for regular live files with safe external-update behavior.
CFPreferences domains use app/defaults export into explicit private snapshot
paths, followed by controlled import. The local `defaults(1)` manual warns
against modifying preferences while the application runs. A blind copy, symlink,
or background restart cannot establish safe restoration. Application Support
files require their own allowlist and consistent capture/restore point.

M10a integrates capture/restore into D10's single cycle. Shared portable settings
apply only where the app is enabled; hardware-dependent settings use explicit
encrypted machine paths. Machine snapshots still synchronize for recovery.
Local edits and received snapshots must survive a deferred restore without one
being recaptured over the other. If the app cannot reload safely, expose pending
restore until it can; do not interrupt a recording or audio route automatically.

Keep credentials sourced through 1Password/2password where possible. Exclude
licenses, authentication state, clipboard/history databases, caches, and recordings.
Audio Hijack's session definitions describe user configuration and belong in
scope. Inventory filenames alone do not establish which keys are portable or
credential-free; verify that during each app's implementation.

Use independent age identities per enrolled machine plus an offline/recoverable
recipient. Keep private identities out of tracking; store recovery material in
the password manager through its documented secure input flow. Test restoration
with dummy secrets before enrolling real files.

Native machine variants and track-local cannot currently combine with encryption.
Use encrypted `private/preferences/shared/<app>/` or
`private/preferences/machines/<stable-id>/<app>/` paths under the active mise
directory instead. Exclude private identities, including `age.txt`, from every
tracking rule. Native launchd declarations remain TOML; generated plists need no
tracked copy. If a plist is captured, its history must be encrypted.

**Limits:** encryption does not hide filenames or remove old plaintext history.
Retiring the tracked Thaw snapshot prevents new public plaintext versions but
does not erase earlier commits. Any historical rewrite is separately scoped.
Hardware/plugin recipients cannot be assumed to work from a background watcher.
Key distribution and the private origin must be ready before enabling automatic
sharing; a missing key must never fall back to plaintext.

Evidence:
https://mise.jdx.dev/dotfiles/encryption.html
https://mise.jdx.dev/dotfiles/history.html

## D8: Existing cask ownership transfer is out of scope

**Closed by D13.** The earlier feasibility gate concerned Homebrew-owned casks
that mise recognizes but does not upgrade as its own. The user chose to reinstall
macOS, so the new setup installs casks through mise from the start. Do not build
receipt conversion, an adoption workflow for the old installation, or a Homebrew
uninstaller. This observation no longer blocks M4 or completion.

Fresh recipe support, pkg/driver installation, updates, and initial macOS privacy
grants still need verification. Mise cannot grant or guarantee preservation of
TCC permissions. Unsupported required recipes need a verified vendor route or
package plugin; replacing an app's function still requires a user decision.

Evidence:
https://mise.jdx.dev/bootstrap/packages/brew-cask.html
https://mise.jdx.dev/bootstrap/packages/macos-app.html

## D9: Synchronize the complete managed setup

**Authority:** the user confirmed all changes, including what gets installed,
when asked whether Fish, editor, and Starship changes should travel automatically.

Include all managed shared configuration, package/tool declarations, plugin
manifests, templates, and required setup code in private history. Apply shared
changes on every enrolled machine and optional-app changes only on matching
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
running machine setup during the planning task.

## D10: Serialize exchange and setup application

**Proposed direction:** one application command owns save/sync/pull and conditional
bootstrap, with a native LaunchAgent scheduling it on automatic Macs. Keep that
trigger separate from the shared command so Linux can later supply its own timer.
Use native history for checkpoints, exchange, conflict resolution, and recovery;
do not implement a second Git synchronization engine.

Keep native `history.sync = "manual"` on both modes while the native watcher
performs local autosaves. The scheduled command provides full automatic exchange
and application; manual machines invoke it on request. This avoids a second
background writer applying incoming files during bootstrap. Machine mode is a
local enrollment setting, not the name of mise's native sync setting.

The command serializes supported mutations, waits for settled and valid inputs,
checks for conflicts or incomplete recovery, exchanges and restores the complete
revision, then applies the platform's base and local app selection. Recheck state
before setup; record success only after required package/config/service checks
pass. Use a setup-input fingerprint plus platform and selection to avoid loops
caused by its own checkpoints. Retry failures with bounded backoff and expose pending,
failed, and applied state. Prove the protocol in M0 before relying on it.

Do not invoke bootstrap synchronously from `[history.reload]`; upstream reserves
those hooks for reloading applications, and nested setup may contend on locks.
Serialize the scheduled path with manual operations and ordinary software setup.
Raw native commands retain their lower-level semantics.

Preference export/import follows M10a within this same serialized command. Save
local app edits before exchange; retain incoming snapshots until a safe restore.
Exclude snapshot-only changes from the package/setup fingerprint. Receiving an
optional app's saved preferences does not enable that app on another machine.
D14 also requires OS compatibility before app capture/restore or package setup;
syncing a macOS module must not run its commands on a future Linux peer.

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

## D11: One common base, individual exceptions, and OpenCode retirement

**Authority:** the user does not use the profile model and explicitly retired it.
Every Mac needs the former cloud, dev, formatters, image, and languages
software. The work Mac excludes web3, streaming, audio, DisplayLink, and the old
window selection. OpenCode is removed everywhere.

Keep retained core plus those five categories in always-loaded modules. Move
DisplayLink out of core. Express the remaining choices per app/tool with native
modules; do not invent replacement work/personal/agent profiles. OBS and its
required plugin can share one capability because they operate together. Keep
BusyCal optional and add Audio Hijack as an optional app/config owner. The
inventory is authoritative for exact members and known work exclusions; other
machines' choices come from fresh enrollment.
Under D14, retain portable capabilities for future Linux use; macOS-only apps
such as OrbStack are common to Macs, not requirements for the mini PC.

Remove profile prompts, aliases, all/subset grammar, and recovery-file handling.
Preserve resumability for the new setup without converting the old selector's
state. Disabling an optional app does not itself delete its data
or grant permission for global package pruning.

Remove OpenCode's runtime declaration, installer/config tree, launch shortcuts,
editor integrations, prompt detection, skills target, schema, and exclusive
dependencies. Do not replace its shortcuts with another assistant without a
separate request. Preserve unrelated terminal/editor functionality and untracked
user data; removal of credentials, sessions, or public Git history is separate.

This supersedes previous requirements to preserve all ten profiles and every
legacy command/test. Retained tools still need working installation/update routes.

## D12: Tests follow retained behavior

**Authority:** the user considers the current suite excessive and poorly focused.
The rebuild should reduce it, not mechanically reproduce it in a new tree.

Keep static syntax/format/schema and secret checks, plus a small real integration
suite for the boundaries this repo owns: safe/repeatable application, Git identity,
encrypted app recovery, and synchronized setup application with machine eligibility.
Use temporary HOME/XDG directories and actual mise/Git/parsers. Exercise failures
that could lose state, apply the wrong identity/software, leak plaintext, or mark
failed work successful. Reuse a case only if it still protects such a contract.

Remove old profile-menu matrices, Stow/Brewfile implementation assertions,
OpenCode checks, legacy migration tests, command-string snapshots, and tests of
internal helper ordering.
Do not retest upstream mise's internals or add tests for each declarative entry.
Use narrow fakes only at real external/privileged boundaries. Keep live package,
TCC, and app-restore acceptance separate from ordinary CI; do not build a complete
cross-product of machines, identities, sync modes, and packages.

Existing quality gates apply until their owner is retired. Update the relevant
instructions and CI together with that retirement. "Fewer tests" must not leave
the new setup's preservation and recovery behavior unverified.

## D13: Fresh macOS setup only

**Authority:** the user explicitly cancelled migration of existing dotfiles
installations and will format and reinstall macOS.

Continue the mise-native repository rebuild, common base, individual app choices,
Git identities, encrypted preferences, and manual/automatic full-setup sync.
Support first enrollment and later restoration from the new private history.
Neither Homebrew nor Stow is installed as part of this setup.

Cancel M13 and remove its dependencies from M14. Remove old/new coexistence,
Stow link conversion, Homebrew receipt transfer/uninstall, migration journals,
legacy runtime adapters, and old-install rollback from the delivery scope and
test budget. Existing source files remain an inventory of useful behavior to
implement, not a requirement to upgrade machines running those files.

Formatting belongs to the user and is not an agent operation authorized by this
planning request. Any local settings the user wants after the erase must first
exist in an independent backup or the new encrypted history. No such capture or
recovery-key enrollment has happened during planning; this is separate from an
in-place migration feature.

## D14: Portable core, macOS first, Linux later

**Authority:** the user may later add a mini PC with Ubuntu or Arch and wants the
design to allow that expansion. Distribution, architecture, and desktop/server
use are undecided. This does not request Linux implementation now.

Keep modules organized by tool/capability. Shared files stay in one place;
platform differences remain beside them. Reject separate macOS/Linux copies of
the whole setup because shared edits would diverge. Also reject unguarded macOS
commands in common modules, which would make future Linux enrollment unsafe.

Use `auto_env = true` in the active global `miserc.toml` for native OS/architecture
fragments such as `mise.macos.toml`; Linux fragments can be added later. Optional
app selection remains independent. Use supported entry filters and target
variants where appropriate, and keep platform commands guarded. A platform
filename alone is insufficient without automatic environments enabled. M0 must
verify these selectors on the chosen release; earlier probes did not test them.

Mise's `apt:` and `pacman:` managers provide future native-package routes while
portable tools remain under `[tools]`. Choose one verified route per capability
on the selected distribution later. The no-Homebrew requirement does not mean
removing Linux's system package manager. Package names and upgrade semantics
require that distribution's own acceptance; no Linux catalog is promised now.

Keep the sync/apply command portable and its launchd trigger macOS-specific.
A systemd user timer is a future scheduling option. Preserve OS/architecture,
app selection, and hardware eligibility through history application; a synced
macOS plist must not cause Linux preference writes. Keep Mac hardware lookup and
platform prerequisites outside shared enrollment/identity logic.

Now: isolate platform behavior and cover selection in the existing composition
smoke case. Later: choose the mini PC's OS/architecture, implement its package,
bootstrap, service, and application paths, then verify clean setup and cross-OS
history exchange there. Do not create empty Linux modules, a provider framework,
or an Ubuntu/Arch test matrix before that work.

Evidence, inspected 2026-10-10:

- https://mise.jdx.dev/configuration/environments.html#platform-environments
- https://mise.jdx.dev/bootstrap/packages/
- https://mise.jdx.dev/dotfiles/managed.html#different-targets-on-different-machines
- https://mise.jdx.dev/bootstrap/services.html

## Continuation

No sync-coverage or installation-scope decision remains open. M0 verifies global
setup composition, fresh package installation/update, and the serial exchange/
application protocol. Actual origin, machine modes, identities, and key references
are enrollment inputs. Completion needs those proofs and fresh-Mac acceptance;
the former Homebrew/Stow ownership-transfer gate is closed as out of scope.
The future Linux distribution is intentionally undecided and does not block the
macOS delivery or D14's portability boundaries.
