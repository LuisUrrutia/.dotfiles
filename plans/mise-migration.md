# Build a mise-native setup, starting with macOS

> Scope update, 2026-10-11: the user brought Ubuntu installation into the current
> implementation and requested a native-capability audit. The Linux deferrals
> below describe the original rollout. Current commands and platform support are
> in `README.md`; current adapter rationale and acceptance evidence are in
> `plans/mise-compatibility.md`. Arch remains deferred. Initial mise installation
> now follows latest stable with upstream SHA-256 verification; tool cooldowns stay.

Status: native repository implementation delivered; isolated verification is recorded
in the compatibility report. Fresh-Mac and real application acceptance remain open.
The user will reinstall macOS; upgrading existing dotfiles installations is out
of scope. A future Ubuntu or Arch mini PC must fit the design without replacing
its shared core; Linux implementation is deferred. No machine setup has started.
Updated: 2026-10-10. Baseline: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`.

Read the [decision map](mise-migration-decisions.md) for authority and tradeoffs,
and the [inventory](mise-migration-inventory.md) for scope. This plan is the
delivery record; update these units rather than creating a competing checklist.
`plans/` is intentionally used because `.gitignore` excludes `/docs/`.
The [compatibility record](mise-compatibility.md) contains executed M0 probes and
the remaining fresh-Mac acceptance limits. Repository work does not install the
setup on the operator's Mac.

## Outcome and acceptance

Mise owns provisioning, supported packages, config deployment, and managed setup
history on a fresh macOS installation. The repository is rebuilt around native
mise capabilities, with a portable core and explicit platform boundaries under
D14. Initial delivery and acceptance remain macOS. Existing-Mac migration is
explicitly cancelled by D13.

Completion requires:

1. Neither the Homebrew executable nor Stow is installed or required for setup,
   updates, configuration, verification, CI provisioning, or selected plugins/tasks.
   Native mise `brew:` recipes may use `/opt/homebrew`.
2. All baseline packages and tool behaviors have a recorded new owner,
   a verified replacement route, or an explicit user-approved retirement. An
   unsupported package or a skipped required resource blocks completion.
3. Fresh installation, repeated bootstrap, updates, and recovery from an
   interrupted new setup work without a legacy package manager or config tree.
4. Each machine selects modules and a manual or automatic private-history mode.
   Managed configuration edits and software declarations travel together.
   Automatic machines apply common and enabled-app changes, including package
   installation; manual machines apply on request. Conflicts pause application
   without overwriting unrelated local work.
5. Personal, work, and agent-machine Git identity cases select the expected
   identity and signing configuration in normal repositories and worktrees.
6. Existing safety contracts remain: supported-platform/non-root checks,
   platform-specific prerequisite order, explicit drift resolution,
   identity fallback, secret exclusion, bounded retry,
   and accurate failure status. Dry runs do not mutate the Mac.
7. Applicable behavioral, syntax/static, broader smoke, and fresh-Mac acceptance
   checks pass. Native bootstrap success alone is insufficient because some
   unsupported/invalid declarations warn or skip.
8. Every backed-up plist is encrypted before its first private-history save.
   Restore covers the actual app configuration, including relevant non-plist
   files. Public sources contain declarations and adapters, not private snapshots.
9. The old profile system and OpenCode integrations are retired. Tests protect
   retained user behavior and data; preserving the old test suite is not a goal.
10. Shared modules, enrollment, and synchronization do not assume Darwin paths,
    commands, or services. Platform-specific resources have explicit eligibility;
    this boundary does not claim that Linux setup is implemented or tested.

Excluded work: an in-place migrator, Homebrew receipt conversion or uninstall,
Stow link conversion, old/new ownership coexistence, and rollback to the legacy
setup. Future reinstallation from the new private history remains supported.

The user owns formatting and macOS reinstallation. Planning does not authorize
erasing a disk, creating the private remote, enrolling credentials, granting
permissions, or modifying live Macs. Saving wanted local preferences before an
erase is a separate backup operation; path discovery is not a completed backup.

## Common setup and machine exceptions

Install one common base on every Mac: retained core plus all software formerly
in `cloud`, `dev`, `formatters`, `image`, and `languages`. These names may still
describe cohesive module folders, but no longer select installation profiles.
OrbStack and its Docker setup therefore belong to the macOS common base. Portable
tools/configuration form the reusable core; macOS apps do not become mandatory
Linux dependencies. Linux package equivalents and its container engine are future
work once the distribution and intended use are known.

Make the remaining optional apps/tools individual machine choices. The work Mac
excludes all former web3 software; OBS, its scene-switcher plugin, Camo Studio;
Focusrite Control, Loopback, SoundSource; DisplayLink; and skhd from the old
window profile. Move DisplayLink out of core. BusyCal remains optional. Add
Audio Hijack as an optional app with preference backup; it is installed locally
but absent from the old manifests. Do not infer other Macs' optional selections.

Use native mise module selection for these individual capabilities, not new
`work`, `personal`, `streaming`, or `all` bundles. Keep package declarations,
app configuration, and any service under the same selection. Git identities and
sync mode remain independent local inputs. The inventory records exact packages
and the complete OpenCode removal surface. D11 owns these scope changes.

## Platform boundary for future Linux support

The user may later add an Ubuntu or Arch mini PC; neither its distribution nor
architecture is selected. Build macOS first, retaining these boundaries now:

- Keep Fish, Git, Starship, editor settings, portable runtimes, and sync logic in
  their owning modules. Isolate macOS package routes, paths, preferences, and
  commands beside them; do not duplicate the source tree per operating system.
- Use native platform environments for OS-specific module fragments and native
  `os` package/tool filters or dotfile target variants for individual differences.
  Platform detection and optional app selection are separate inputs, not profiles.
- The official mise installer/enrollment path dispatches by detected OS and
  architecture before mutation. FDA/CLT, `ioreg`, `/Applications`, `~/Library`,
  `defaults`, and `launchctl` belong only to the macOS path. Common code uses HOME,
  appropriate XDG/application paths, and resolved executable locations.
- Keep the serial sync/application task independent of scheduling. Its macOS
  trigger is launchd; Linux can later use a systemd user timer. Incoming history
  may contain foreign-platform modules or encrypted snapshots, but apply/capture/
  restore selects only compatible resources and this machine's enabled apps.
- Keep machine IDs and identity inputs independent of the macOS hardware lookup.
  Preserve current public records; defer Linux registration and package mapping.

Mise can orchestrate `apt:` or `pacman:` for native Linux dependencies. Their
availability is not a decision to install both, and a missing required manager
must not count as success. Do not force macOS brew recipes onto Linux or select
a distro, desktop, AUR helper, or replacement app during this macOS delivery.
D14 records the evidence and deferred acceptance.

## Proposed structure and ownership

Design the repository as a native mise configuration tree. The user explicitly
rejected preserving Stow's directory layout. Group files by the capability that
owns them, keeping a module's package declarations, deployment rules, sources,
templates, and necessary scripts together. This is the proposed destination, not
the current filesystem:

```text
.dotfiles/
  install.sh                      official mise and first-use prerequisites
  mise.toml                       repo verification and enrollment adapter
  config.toml                     shared mise policy and setup defaults
  miserc.toml                     native automatic platform environments
  conf.d/
    fish/
      mise.toml                   shared shell, files, and plugin setup
      mise.macos.toml             macOS installation and integration
      config.fish
      fish_plugins
      conf.d/                     Fish startup snippets
      functions/
      completions/
    git/
      mise.toml
      defaults.gitconfig
      ignore
      identity.gitconfig.tera
      scope.gitconfig.tera
    starship/
      mise.toml
      starship.toml
    zed/
      mise.toml
      settings.jsonc
      keymap.jsonc
    macos/
      mise.macos.toml             defaults and native LaunchAgents
      system-settings.sh          only behavior outside native declarations
    orbstack/
      mise.macos.toml             common on every Mac
    cloud/
      mise.toml                   common cloud tools
    linearmouse/
      mise.macos.toml             app and encrypted mutable config
    thaw/
      mise.macos.toml
      preferences.sh              capture/restore through app/defaults APIs
    supercmd/
      mise.macos.toml
      preferences.sh
    loopback/
      mise.loopback.toml           selected only on machines that use it
      preferences.sh
    obs/
      mise.obs.toml               app and its required plugin together
    displaylink/
      mise.displaylink.toml       optional driver
    cli/
      mise.toml                   portable CLIs without their own module
      mise.macos.toml             native macOS package routes
    apps/
      mise.macos.toml             common Mac apps without managed config
  tasks/                          shared native operational commands
    sync
    update
    config
  bootstrap/                      first-use prerequisites and enrollment
  machines/                       public enrollment records
  tests/                          small behavior suite and format checks
  plans/
```

Other capabilities follow the same pattern; the tree is illustrative,
not a reduction of the inventory. Keep a source beside its manifest when the
module is small. Add a `templates/` or `scripts/` subdirectory only when the module
needs that grouping. Preserve real application structure, such as Fish's
`functions/` or Neovim's `lua/`; remove synthetic HOME paths and generic wrappers.

`conf.d/fish/mise.toml` maps source files explicitly, for example:

```toml
[dotfiles]
"~/.config/fish/config.fish" = "config.fish"
"~/.config/fish/functions" = { source = "functions", mode = "symlink-each" }
```

A relative source resolves beside its manifest. This example needs neither
`config/.config/fish` nor a copy of `mise.toml` in the live Fish directory.
Use similar entries for Fish snippets, completions, and the plugin manifest.
Native groups remain useful for a homogeneous source tree; they are not the unit
of module selection and need not mirror HOME.

Use `mise.toml` for portable common setup, `mise.macos.toml` for macOS resources,
and `mise.<app>.toml` for an optional capability. Set `auto_env = true` in the
enrolled global `miserc.toml`; platform filenames do not select themselves by
default in the inspected mise releases. Verify this in M0. Add Linux fragments
beside their module sources when implementing that platform, not empty folders now.

For example, local `env = ["loopback", "obs"]` loads those two modules. This is
mise's module mechanism, not a replacement profile taxonomy. No extra module
index, copied package list, profile aliases, or selection menu is needed. Keep
all optional-only files/services/packages in the optional fragment. Empty local
selection still installs the platform's complete common base. An optional app
must also match its OS; selecting Loopback must not bypass macOS eligibility.
Use supported entry filters or guarded tasks, not an invented combined suffix.
Remove old profile flags, menus, and saved-selection handling; there is no legacy
selection converter.

The active shared payload has the same relative layout under `~/.config/mise`:

```text
~/.config/mise/
  config.toml
  miserc.toml                     shared platform-discovery policy
  conf.d/                         manifests and source files together
  tasks/                          shared operational tasks
  private/preferences/            encrypted history inputs, never public seeds
  miserc.local.toml               this machine's environment selection
  config.local.toml               local origin, mode, and identity inputs
```

Private history owns shared contents of this active tree and explicitly tracked
live app files. Preference snapshots have their own encrypted tracking entries;
a broad plaintext source rule must not capture them. Local files, credentials,
generated machine outputs, locks, logs, and history storage retain their separate
policies. There is no second active
source tree at `~/.local/share/dotfiles/setup/`. Native mise state remains in its
state directory; runtime state is not stored inside source modules.

The public checkout stays separate. First enrollment copies only the native
payload into missing regular active files, without `.git`, repository `mise.toml`,
bootstrap tooling, or tests. Later Macs restore the private setup via adoption.
Do not clone the public Git repository into the active directory as an enrollment
shortcut: private setup adoption checks a pre-existing checkout's origin. Public
updates are explicit diff/merge imports; public publication is reviewed promotion.
An older seed must never replace newer active contents. M0 proves this protocol.

Use native mise commands and tasks as the operational route. Any retained
`dotfiles` command is a thin convenience wrapper; old CLI grammar is not a
compatibility requirement. Remove the old `cli/`, `config/`, and `maintenance/`
implementation layers as useful behavior moves to native owners. The root
repository `mise.toml` does not duplicate machine resources. Run active bootstrap
from a neutral directory and prove same-run tool resolution.

| Path category                           | Runtime owner                                   | How changes travel                                           |
| --------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| Module manifests and supporting sources | Active `~/.config/mise/conf.d/`                 | Private history, then common/enabled-app bootstrap           |
| Shared operational tasks                | Active `~/.config/mise/tasks/`                  | Private history, then serialized execution                   |
| Generated machine Git includes          | Module templates plus local machine inputs      | Shared input changes travel; outputs stay machine-scoped     |
| App-written managed regular files       | Live file plus private history                  | Save/sync/pull; no recurring seed overwrite                  |
| App preference exports                  | Private encrypted snapshots plus module adapter | Save/sync/pull, then restore only on an eligible app/machine |
| Public baseline and tests               | This Git repository                             | Explicit reviewed import/promotion                           |
| Local-only preferences and enrollment   | Local files/history                             | Never exchanged by default                                   |
| Credentials and sessions                | Existing secret/app owner                       | Excluded, or explicitly encrypted eligible file              |

Do not track the public checkout. Tracking a symlink records its link, not the
source content; explicitly track the shared native payload. Keep real live
directories so applications cannot write runtime data into the module tree.

The supported software-add path records the tool/package/plugin in its owning
module before installation. Shared declarations reach all machines; optional
fragments apply only to compatible machines enabling the app. Explicit machine-only
additions remain local. Preserve version policies and OS/hardware eligibility,
not installed binary copies. Report unmanaged installations for enrollment.
These contracts also apply when an agent changes the setup.

## Delivery order

The implementation uses one coherent replacement boundary because the native
payload, operational commands, verification and legacy retirement must agree.
The statuses below distinguish repository delivery from real-machine acceptance.
No PR or machine installation was requested as part of this implementation.

| Unit    | Result                 | Implementation and evidence                                                                                          |
| ------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------- |
| M0      | Native compatibility   | 2026.10.7 selected after the structured-edit probe; isolated contracts verified                                      |
| M1      | Official bootstrap     | Implemented; verified download, checksum rejection, preserved replacement, and rerun                                 |
| M2      | Enrollment             | Implemented; tracked missing-file seed, actual adoption with all setup phases skipped, local choices preserved       |
| M3/M4   | Software ownership     | 162 native package declarations and 25 retained tools mapped; full fresh installation/update remains open            |
| M5      | Native file ownership  | Implemented; isolated deployment, partial-key capture, foreign-link and drift preservation pass                      |
| M6      | Git identities         | Implemented; personal/work/agent/unknown cases and real Worktrunk worktrees pass                                     |
| M7      | Fish                   | Implemented; syntax and noninteractive smoke pass; actual login shell/plugin startup remains open                    |
| M8a/M8b | macOS settings         | Native defaults, agents and remaining tasks implemented; privileged and GUI execution remains open                   |
| M9      | Tool setup             | Native module tasks implemented; fresh package/plugin execution remains open                                         |
| M10     | Private history        | Native first-save encryption, adoption/key failure and local exclusion verified                                      |
| M10a    | Preferences            | Capture/restore adapters and reviewed structural guards implemented; real app reopen remains open                    |
| M10b    | Serial application     | Two-client native exchange, automatic task application, conflict stop, revision changes and process cleanup verified |
| M11     | Maintenance            | Serial, independent failure handling and success-only schedules implemented; real updates remain open                |
| M12     | Verification/CI        | Four integration areas and parser/static checks implemented; hosted workflow execution remains open                  |
| M13     | Existing-Mac migration | Cancelled by the user; no migration implementation                                                                   |
| M14     | Cleanup and acceptance | Legacy tracked runtime removed; disposable fresh-Mac acceptance remains open                                         |

M3/M4 and M6-M10b need not form one linear PR stack. Dependencies name required
capabilities; changes to shared entrypoints require coordination, not artificial
functional dependencies. Each unit carries the verification needed for its
behavior; declarative moves do not each need a new test suite. Do not detach
required tests or hide bulk removals to meet the estimated review size.

## M0: Prove the consequential seams

Use disposable HOME/XDG trees and disposable macOS environments for system work.
Never use the operator's live app directory or history origin for a probe.

- Select an official mise release that supports the used schemas and has passed
  the repo's release cooldown. Record version, architecture, release date, and
  verified download digest. Set the eventual `min_version` from evidence.
  Installed mise is 2026.10.1; current documentation includes newer behavior.
  `mise vars --json`, for example, was unavailable in the installed build.
- Prove D3's first-use regular global-config enrollment, later private adoption,
  common/optional module selection, deployment selection, history visibility,
  same-run runtime availability, and single hook execution. Public seed reruns
  must preserve private edits. Keep the public checkout separate and prove the
  allowlisted payload excludes repository tooling. Verify different home paths;
  relative group roots and relative entry sources resolve differently.
  Include D14's automatic platform environments and their precedence alongside
  optional selections. Prove foreign-platform declarations stay inactive on the
  tested host; document this as a composition check, not Linux acceptance.
- Prove D10's serial save/sync/pull/bootstrap protocol with two clients, an
  autosaving watcher, local mode overrides, and no second incoming writer. Test
  settled complete source/config revisions, native lock behavior, interrupted
  pull, validation failure, and bootstrap-generated checkpoints without loops.
  Identify usable native status/revision interfaces before implementing a worker.
- Verify the retained target map from the source inventory using native mise in
  a temporary HOME. Check missing optional apps, source membership, real app
  directories, and refusal to overwrite unknown files. No Stow conversion probe.
- Build a package ledger from the retained inventory: OS/architecture eligibility,
  intended manager, fresh installation, dependencies, updates, and recovery.
  Installed Homebrew state and receipt transfer are not inputs to the installer.
- On disposable Macs, prove fresh formula and cask installation/update,
  self-updating apps, font/binary artifacts, pkg installation, third-party taps,
  and unsupported-recipe failure. No Homebrew cask handoff is required.
- Check the existing sudo broker contract against mise's actual noninteractive
  behavior. A cached sudo timestamp is not assumed sufficient. Do not add
  passwordless sudo policy or run the whole bootstrap as root.
- Verify one encrypted binary/XML plist round trip and one real app's safe
  capture/restore lifecycle before committing to M10a's adapter contract. Local
  path discovery alone does not prove portable contents or successful restoration.

Produce a committed compatibility report and refine later drafts. A successful
metadata dry run does not prove installation, upgrading, app permissions, or
successful first launch. If a gate fails, pause only its dependent work and record
the observed failure and smallest alternative experiment.

## M1: Start without mise, Fish, or Homebrew

Refactor the first-use path in `install.sh`/`bootstrap/`, retaining useful safety
and dry-run flags while retiring profile selection. Run on stock `/bin/bash` 3.2,
regardless of the user's current zsh shell.

Keep platform dispatch separate from common download/enrollment logic. Initially
accept only the tested macOS target; an unsupported OS must exit before running
macOS prerequisites or installing anything. Linux bootstrap remains future work.

On macOS, preserve Full Disk Access, Command Line Tools, and validated sudo order.
When CLT is missing, launch Apple's installer interactively and exit for rerun;
automation reports the prerequisite instead of waiting. CLT provides initial
Git/SSH, avoiding mise's possible host-package-manager fallback before cloning.

Install an official mise release into `~/.local/bin`, with a verified pinned
installer or release digest and no `curl | sh` dependency in the trusted path.
Do not require GPG/minisign to exist on a fresh Mac without bootstrapping them.
Keep an existing newer compatible binary; preserve rollback material for an
actual replacement. Explicitly establish PATH for the current run and future
stock-shell sessions. Use only SSH for cloning the dotfiles repository.

Seed `config.toml`, `miserc.toml`, `conf.d/`, and `tasks/`, or restore the existing
private setup, without overwriting unknown config. Then invoke the
effective setup. Preserve resumability and do not write the install marker when
a required phase fails. Distinguish a first `--from --dry-run` that only reports
cloning from a full configuration preview.

Acceptance: no-mise/no-brew environment, failed download/checksum, missing CLT,
missing FDA, unavailable sudo, existing config conflict, dirty checkout, rerun
after interruption, and tools available without reopening the shell. Use the
existing bootstrap/environment tests as evidence of retained behavior. Keep only
tests that exercise the new public boundary; discard old call/fixture plumbing.

## M2: Native modules and machine enrollment

Replace the old selector with enrollment of the common base and individual
optional modules. Install the common base from D11 on every Mac, including unknown
hardware. Optional modules have one local selection owner and no umbrella presets.
Apply the work exclusions from the inventory. Old aliases and selection files
have no compatibility or conversion path.

Keep public machine data tracked and express its values through the new native
enrollment schema. No legacy shell-variable adapter is required. Generate local
selection/overrides without replacing unrelated mise settings. Model optional
modules, Git identities, and sync mode separately. Keep mode/origin local;
incoming config must not enable automation or change another machine's selection.
Treat OS/architecture as detected facts, distinct from user selections and stable
machine identity. Keep the current `ioreg` lookup in the macOS enrollment path.

Acceptance: inspect the real effective configuration for an empty optional list,
the work selection, and one optional audio/app module. All include the common
base; work contains none of its excluded resources; incoming history preserves
local selection and mode. Remove the old profile-menu/alias tests. Both sync
modes use native `history.sync = "manual"`; M10b owns scheduling. Verify that
one-run `-E` replaces the optional list without disabling platform constraints or
accidentally widening selection.

## M3-M4: Install and maintain packages through mise

Use the inventory plus D11's retirements/additions as the completeness baseline.
Preserve current version channels and deliberate trust/cooldown exceptions unless
compatibility requires a reviewed change. Avoid unrelated tool-manager churn
while removing brew.
Scope native macOS package routes explicitly, even when a backend can also run
on Linux. Preserve one package owner per capability on each supported platform.

M3 maps remaining native formulae to `bootstrap.packages` and retains current
`[tools]` declarations except OpenCode. Use canonical names and stable paths for
native libraries and keg-only tools. Replace executable `brew --prefix` lookups
with verified mise package-location queries or declared paths; the prefix can
still be `/opt/homebrew`. Validate dependency installation and an actual upgrade
with the Homebrew executable absent. Preserve a dependency's real installation
path without retaining legacy `brew` discovery helpers.

M4 installs apps/fonts through `brew-cask:` from the start. Prioritize Slack,
Discord, Zoom, ChatGPT, and T3 Code for self-update and permission checks. Cover
macFUSE/sshfs, DisplayLink, VPN/security apps, OBS plugins, and third-party taps.
Record unsupported artifacts instead of treating skipped entries as success.
Include Audio Hijack's installation/update owner. Apply each optional package's
machine eligibility before installing, configuring, or starting its helpers.

Install `mas` before App Store operations; do not rely on a `[tools]` install that
occurs after packages in the same bootstrap. Test manager ordering or make this
dependency an explicit prior phase. Preserve Xcode opt-in and separate its
download from license/first-launch steps. Missing App Store login is a visible
prerequisite, and purchase/claim is manual.

Use `macos-app:` only for supported app archives with explicit version and
checksum. It is not a generic pkg/driver installer or automatic release updater.
For a proven unsupported recipe, use an upstream binary or a bounded vendor task/
package plugin with status, installation, update, and recovery behavior. Do not
fallback to brew or replace an app's function without a user decision.

Acceptance per batch: fresh install, second apply, upgrade, failure/retry,
dependency resolution, running self-updating app, and reported manager. Validate
application launch and initial GUI permission enrollment on a logged-in Mac,
then check the update path. Recipe compatibility remains a gate; converting
Homebrew-owned installations does not.

## M5: Native modules and safe file deployment

Move each capability into `conf.d/<capability>` and keep its native declarations,
config sources, templates, and necessary tasks together. Remove Stow's synthetic
`config/.config/<tool>` and `config/Library/...` path prefixes. Explicit target
entries preserve the actual destination. Do not copy whole legacy Tool Installers
into new module folders as the default implementation.

Use source-relative `[dotfiles]` entries for individual files and `symlink-each`
for real application subtrees. Use groups only where a source tree naturally
shares deployment policy. Exclude manifests, setup scripts, and templates from
recursive app deployment. Cover the retained source inventory and explicit target
map without implementing Stow conversion. A Git manifest can check public
seed membership but is not a runtime index for regular active sources.

Track active source contents explicitly. Translate meaningful Stow exclusions,
then remove Stow control files from the new source tree. Keep local Git identity,
generated Fish files, and VoiceInk authentication/runtime data excluded. OpenCode
sources are retired under D11; its local data is not an installer input.
Update `$DOTFILES` references, canonical agent instruction source links, task
paths, and source-relative includes to the active tree rather than leaving hidden
dependencies on the public checkout.

Reuse `config/run.sh`'s public inspection and explicit capture/discard semantics.
Before applying, check the complete selected target set, ancestor symlinks,
foreign links, changed regular files, type conflicts, and duplicate owners.
Back up before a reviewed transition; no automatic adopt, force, or deletion.
Keep inspection success distinct from mutation success.

Use structured merge entries for the Codex settings currently merged by awk,
preserving plugins and other unrelated keys. Evaluate Claude settings the same
way. JSONC is not supported by native merge: retain a suitable whole-file owner
or a format-aware task for Zed and other comment-bearing formats.
Keep platform-specific paths and commands out of shared Git/Fish/editor defaults;
isolate credential helpers, signing-program paths, clipboard commands, and macOS
Fish functions/abbreviations in eligible fragments or explicit OS guards.

Acceptance: retained target coverage, clean second apply, app replacing
a symlink, identical unmanaged file, changed copy/template, foreign parent/link,
source removal, permissions, safe capture, safe discard, and orphan cleanup.
Also test source-content sync behind links, seed/import preservation, and public
promotion without exposing private or local data.
Consolidate useful cases from lifecycle/resolution and owned-key merge tests into
a small real-filesystem suite; do not preserve tests of the retired resolver.

## M6-M9: Preserve machine and tool behavior

**M6, Git:** implement D5 with deterministic templates and explicit identity
inputs, no template `exec()` or secret values. Generate the entry file and scoped
includes with canonical include order; preserve unrelated keys on later runs.
No conversion of the legacy Git layout is required. Test default/scoped
identity and signing inside/outside the chosen directories, nested paths,
worktrees, paths with spaces, unknown machines, and absent optional signing tools.
Keep Git authorship, SSH account selection, and gh actor selection distinct.
Retain identity and unrelated-key preservation cases; remove legacy migration tests.

**M7, Fish:** install Fish before setting the login shell. Use native
`bootstrap.user` for `/etc/shells` registration and shell selection when its
behavior passes the current contract. Preserve early PATH setup, completions,
Fisher's manifest, plugin ownership, interactive-only policy, and subprocess
behavior. Evaluate native auto activation against the current early `02_mise`
owner; native activation may skip a whole-file-managed config. Choose exactly one
owner and verify commands needed by later `conf.d` files are already available.
Invoke the repository's Fish debugging skills during this implementation.

**M8a, defaults/agents:** translate each user preference with its type, host scope,
and nested dictionary semantics. Preserve unrelated shortcut keys. Keep optional
app/container failures distinguishable from invalid declarations. On 2026-10-11,
the user selected a native complete Dock layout: Messages, optional BusyCal,
Notes, Ghostty, Zed, T3 Code, Dia, App Store, and System Settings. Native `apps`
owns that order and requires every referenced app to exist. This replaces the
earlier requirement to preserve relative dockutil edits.

Implement the 10:00/20:00 appearance schedule as a native LaunchAgent with
graphical-login, wake, and idempotency behavior. No old-label handoff is needed.
Native agents use `dev.mise.*` labels and do not cover arbitrary system daemons
or every plist key. Without a graphical session, preserve deferred activation
behavior.

**M8b, system tasks:** retain narrow tasks for `scutil`, `pmset`, privileged
software-update defaults, firewall policy, FileVault, effective screen lock,
login items, associations, and other unsupported operations. Preserve independent
step reporting and aggregate failure. Recovery keys remain outside history and
logs. Native preference rollback does not undo these system operations.

**M9, other tools:** use the inventory's installer disposition. Retain setup for
bat caches, Ghostty validation, Neovim/Lazy/Mason, TPack, GH extensions, Skills,
Rust components, completions, OrbStack Docker links, associations, and VoiceInk.
M10a replaces Thaw's plaintext backup path. Remove OpenCode's integrations and
exclusive dependencies using the inventory's consumer map; preserve unrelated
editor, terminal, and assistant behavior without choosing a replacement assistant.
Call tool-scoped tasks explicitly; the old installers are reference material,
not a runtime dependency of the new setup. Keep module tasks beside sources and
shared operational tasks in native `tasks/`. Use task dependencies and `mise exec`
or resolved paths instead of interactive shell initialization. Test launchd
environments separately from shell PATH. Keep retained command wrappers working.

## M10: Complete setup history and private enrollment

Create an allowlisted global history policy covering effective configuration,
the native `config.toml`, `conf.d/`, and `tasks/` payload, including package/tool
declarations, plugin manifests, templates, and required setup code. Keep public
checkout files outside history's write ownership. Track regular live files or
source contents behind links; seed only when absent. Versioned public import and
promotion use explicit diff/merge.

Keep origin, mode, local optional-app selection, auth references, and application
stamps local. Use machine variants for suitable nonsecret hardware-specific state,
with stable identity recovery after reinstall. Preserve tracked public machine
records while keeping their generated private/local enrollment outputs distinct.

Configure encryption before the first save of every backed-up plist and other
private app settings. M10a owns capture and restore; D7 owns recipients/recovery.
Use synthetic valid plist data to prove ciphertext storage, authorized restore,
missing-key failure, and recovery. Keep age identities, authentication sessions,
licenses, tokens, databases, logs, and caches excluded. Audio Hijack session
definitions are configuration, not authentication sessions. Exclude `age.txt`
explicitly from tracking. Do not combine machine variants with encryption or
assume an SSH agent can decrypt age history.

Use mise's native watcher for local autosave. Set native `history.sync = "manual"`
in local policy on both machine modes; M10b schedules explicit native exchange
and subsequent setup only on automatic machines. Verify background SSH access
without secrets in LaunchAgent environment or incidental authentication changes.
Enrollment needs the actual private origin and key references.

Acceptance: two isolated clients and a temporary Git origin demonstrate changes
in both directions, module manifest/source restoration together, simultaneous edits,
unsaved changes, interrupted pull/recover, undo, and preserved local selection.
Verify local autosave alone neither exchanges nor installs. Local-path transport
is only a test fixture; real-origin acceptance uses SSH. Repeat bootstrap and
public enrollment without reverting synchronized files. Existing lifecycle tests
do not replace dedicated history integration tests.

## M10a: Capture and restore application preferences

Cover Thaw, LinearMouse, SuperCmd, SoundSource, Loopback, and Audio Hijack using
the locally discovered paths in the inventory. Keep only small app-specific
adapters beside their native module manifests; mise owns encryption, history,
exchange, and recovery. Do not build a general backup framework.

Use `mode = "track", encrypt = true` for eligible regular live config files,
including LinearMouse's JSON, created as a regular file on the fresh setup.
Prove the app's external-edit/reload behavior before allowing direct restore.
For CFPreferences domains, capture with `defaults export` or the app's supported
export API into `~/.config/mise/private/preferences/`. Restore through the
corresponding API after validating types, app version, and required keys. Plain
copy/symlink ownership of a live preference plist is not the default.
Do not also declare fixed bootstrap defaults for mutable app keys: a second owner
would reset the GUI changes this workflow is meant to capture.

Application Support files need an explicit allowlist and a consistent capture
point. Include actual presets/device/session definitions; exclude helper bundles,
recent-item lists, recordings, caches, clipboard databases, and credentials.
Prefer an app-supported export where available. Validate persisted contents with
`plutil`/the actual parser; do not treat a successful file copy as a working backup.

Every captured plist is encrypted from its first checkpoint. The same rule covers
companion private JSON/config files. Use separate encrypted snapshot paths under
`shared/<app>/` and `machines/<stable-id>/<app>/` when necessary: portable settings
can apply on enabled machines; device IDs, display layouts, and hardware routing
must not overwrite another Mac's setup. Machine-scoped captures still travel for
recovery. Native encrypted machine variants are unavailable. Scope each app's
fields during its implementation before enabling automatic restore.

Integrate capture before save/exchange and restore after a complete pull into
M10b's existing serialized cycle. On automatic machines, capture local app edits
without requiring manual backup. Never recapture stale live values over a received
snapshot awaiting restore; compare with the last applied snapshot and retain both
versions on a conflict. App exports must settle atomically before history saves.
Keep snapshot-only changes out of the package-install trigger.

Restore only enabled apps with a compatible schema and hardware mapping. An app
or helper with unsafe active writes leaves restore visibly pending until it can
reload safely; do not kill an active recording, audio route, or user session.
Use native reload hooks only for a proven safe app reload, never full bootstrap.
An optional app's history may arrive on the work Mac without starting that app,
writing its live preferences, or installing it.

Remove `tools/thaw/Thaw.plist`, timestamped plaintext backup output, and the
`thaw-config` implementation from the rebuilt repository. Redirect the
useful backup command to the new capture operation. Earlier public Git commits
remain plaintext; rewriting public history is separate work, not an effect of
enabling mise encryption. Native LaunchAgent definitions stay in TOML, with
generated runtime plists outside version control.

Acceptance: a synthetic valid plist survives encrypted save/restore with types
intact, missing keys fail closed, and a received snapshot does not overwrite
unapplied local edits. On macOS, demonstrate one changed setting per supported
app survives capture, restore, and reopen; inspect sessions/devices where relevant.
Check disabled apps, pending active-app restore, and machine-bound data once at
the adapter boundary, not with a separate mocked system for every plist.

## M10b: Apply synchronized software and setup

Expose one serial exchange/application command for both modes; automatic machines
schedule it through native launchd on macOS; manual machines run it explicitly.
Keep scheduling outside the common command so Linux can later supply a timer.
Keep a single incoming apply owner. Reuse native mise checkpoint/conflict/recovery
semantics rather than writing a new Git synchronization engine.

The cycle waits for settled valid managed inputs, captures eligible app settings,
saves intended changes, checks native conflict/recovery status, syncs and pulls
the complete revision, then rechecks state and runs effective bootstrap for the
local selection when needed.
M10a restores changed app snapshots separately after prerequisite setup succeeds.
Do not force conflict choices or run setup after a partial pull. Serialize with
manual configuration and installation operations. M0 must prove status and lock
interfaces; do not infer success from files appearing in place.

Track a fingerprint of effective setup inputs, platform, and local selection,
plus pending, failed, and applied results. Mark applied only after verification.
Coalesce repeated wakeups; retry failures with bounded backoff. Bootstrap may
create checkpoints, so a changed history commit alone must not retrigger setup
indefinitely. Do not call setup synchronously from `[history.reload]`.

Record software additions in the relevant declaration before local installation.
A failed install leaves declared intent and a visible pending result for retry.
Propagate package/plugin/version changes; locally resolve artifacts according to
platform and version policy. New source/task files must be enrolled together
with the declarations that reference them before publication.
History exchange does not widen platform eligibility. Foreign-platform changes
must not invoke local installers or preference adapters, nor count as missing
local requirements. Preserve those sources for eligible peers.

Automatic mode includes running received setup code as the enrolled user. Missing
sudo, App Store login, TCC consent, or GUI interaction produces a visible pending
prerequisite; it never blocks on stdin or silently succeeds. Do not alter sudo
policy. Declaration removal is shared, but destructive uninstallation or unknown
file deletion still requires the established explicit handling, not global prune.
History rollback restores inputs and cannot promise package downgrades.

Acceptance: exchange a Fish/Starship edit, a shared package addition, an optional
app package, and a manifest plus new task/source between clients. Verify
matching automatic receivers apply them, disabled apps remain inactive, and
manual receivers install only after explicit exchange/application. Also cover
invalid config, conflicts, edits during a cycle, offline/auth failures, failed
installation and resume, permission prerequisites, interrupted restore, duplicate
wakeups, and self-generated checkpoint loops. Prove actual received package
installation on a disposable Mac; fake executables cannot establish that result.

## M11-M12: Daily operations and verification

M11 ports `maintenance/update.sh` behavior into native operational tasks: official
mise self-update, versioned tools, native packages, App Store, and existing plugin
maintenance. Preserve scheduling gates, independent error reporting, successful
mutation stamps, and `--ignore-schedule`. Do not run global prune, repository
pull, or history pull as an incidental software update. Expose useful operations
through native tasks and selected Fish shortcuts; old CLI compatibility is not
required. Add the declared-software workflow and explicit full-setup sync command;
share the application lock with M10b. Replace the Thaw-only plaintext backup with
M10a's encrypted preference
capture; preserve the useful command without its old storage implementation.

M12 keeps a small behavior suite and useful schemas under `tests/`, exposed
through repository mise tasks and any retained convenience command. Provision
the toolchain through mise on `macos-26`, port Brewfile/Stow groups to native
declaration/ownership and temporary-HOME deployment checks, and remove formats
verification's `brew --prefix ruby` dependency. Keep CI and local
verification on the same command. Use the GitHub Actions skill when changing CI.
Enforce no duplicate package/file owner and no undocumented required-resource
skip. D12 defines the test budget. Remove obsolete profile/Stow/Brewfile and
OpenCode tests with their owners, exact shell-command snapshots, and helper-level
tests that add no distinct user-visible protection. Validate manifests with native
mise/parsers; do not reproduce mise's package, template, or history internals.

## M13: Cancelled

The user chose to format and reinstall macOS. Do not implement a legacy-state
importer, receipt handoff, Stow link converter, Homebrew uninstaller, migration
journal, or old/new coexistence. The identifier remains only to make the scope
change explicit; M14 has no dependency on M13.

## M14: Fresh-Mac acceptance and repository cleanup

1. Start from stock macOS without mise, Fish, Homebrew, or Stow. Complete the
   documented prerequisites, install official mise, and enroll the common setup
   plus this machine's optional apps, identities, and sync mode.
2. Verify app launches, plugins, Git identity, shell startup, and service state.
   Exercise initial permission grants, interrupted-install resume, and repeat
   bootstrap without replacing user edits or reinstalling working resources.
3. Run setup, updates, and repository verification with no `brew` or `stow`
   executable. Check absolute invocations as well as PATH-based calls. The mise
   bottle prefix may still be `/opt/homebrew`.
4. Exercise manual and automatic sync, the work exclusions, cross-machine
   software additions, and encrypted app recovery. A later clean Mac can enroll
   from the new private history. Keep automation disabled until enrollment and
   required setup checks pass.

Exercise the three Git identity shapes in focused Git fixtures, not a full
package/machine cross-product. Target-Mac and GUI acceptance still need execution;
unsupported required recipes remain blockers.

Remove obsolete Stow/Brewfile orchestration, old installers, and legacy-only tests
from the rebuilt repository once retained behavior has its native owner. No
backward-compatible installer is required. Preserve public machine data and useful
configuration sources. Update README, POST_INSTALL, CONTEXT, relevant AGENTS
instructions/skills, and package ownership documentation to describe the fresh
setup. Use instruction-authoring skills when changing agent guidance.

## Verification contract

Apply D12: each maintained test must identify a meaningful regression in behavior
this repository owns. A declarative move needs native parsing and a focused smoke
check, not a new installer mock suite. No coverage percentage or legacy test count
is a completion target. The inventory records examples to remove or consolidate.

There is no application compilation step. Keep syntax/static/config validation
for the remaining languages, secret scanning, one broader smoke path, and
`git diff --check`. Record exact commands and outcomes per unit. Existing project
gates apply while their owner remains; retire superseded commands and their AGENTS
requirements in the same change as the old implementation.

Maintain a small number of integration scenarios using real mise, temporary
HOME/XDG trees, and real parsers/Git. Cover preservation and repeat apply; default
and scoped Git identity; encrypted capture/restore; and manual/automatic exchange
with optional-app eligibility and failure recovery. Consolidate related cases
within those scenarios. Mock only unavailable external/privileged boundaries;
assert resulting files and behavior, not internal function or CLI-call spelling.

Retain relevant bootstrap prerequisite/dry-run and maintenance failure contracts.
Drop profile menu/alias matrices, legacy-link conversion, old Git layout migration,
and Homebrew handoff tests. Validate native targets in a temporary HOME. Continue
`fish --no-execute` and tests of affected interactive versus subprocess behavior,
not plugin fixture internals. Repository gates for still-unchanged old code remain
applicable until that code and its gate are removed together.

Add platform selection to the existing effective-config/eligibility smoke case;
do not add a distribution matrix now. Mac-only resources and paths must stay out
of portable declarations. Real Ubuntu/Arch installation and cross-OS sync tests
belong to the later Linux implementation on the chosen distribution.

M0's compatibility experiments and fresh-Mac acceptance are not an exhaustive
CI matrix. Keep package ownership/upgrade, App Store authentication, TCC, login/
wake, and app preference restore in a short macOS acceptance checklist. Run it
for the affected implementation or dependency change; do not download every app
for each docs/config edit. Fakes cannot establish these integration results.

Inspect both `mise bootstrap --dry-run` and component statuses. The declarative
`bootstrap plan` does not cover every bootstrap part; neither preview proves
template results, application permissions, or a successful fresh installation.

## Recovery of the new setup

Resume an interrupted fresh bootstrap from completed work and accurate statuses;
never mark a failed required step as installed. Repeated apply preserves unknown
files and user edits. Use native history and explicit conflict handling to restore
managed configuration after enrollment. App preference restore still follows its
safe reload and encryption policy.

Package recovery may require retrying or reinstalling an artifact; history does
not promise package downgrades. For system settings, record prior values when
feasible and document steps that require manual recovery. There is no rollback
to the former Homebrew/Stow installation.

Mise history undo restores tracked files, not installed packages, macOS privacy
grants, or the full system. Keep its state directory and machine identity intact.
Files not captured before the user's disk erase are not recoverable through the
new history. Pre-erase backup is separate from fresh setup; none has been taken
as part of this planning work.

## Readiness and next action

Repository implementation is complete against the isolated checks recorded in
`mise-compatibility.md`. The user owns reinstallation and the separately supplied
private origin/recovery keys. Next, use `POST_INSTALL.md` on an authorized fresh
Apple Silicon Mac, record package results in `mise-package-coverage.tsv`, and
complete real app capture/restore/reopen acceptance. No live preferences were
backed up and no machine was enrolled during repository implementation.
