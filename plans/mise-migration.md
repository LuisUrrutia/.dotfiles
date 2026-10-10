# Migrate the macOS dotfiles repository to mise

Status: planning only; common setup, application exceptions, encrypted preference
history, OpenCode retirement, and proportionate verification are agreed direction.
No implementation or machine migration has started.
Updated: 2026-10-10. Baseline: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`.

Read the [decision map](mise-migration-decisions.md) for authority and tradeoffs,
and the [inventory](mise-migration-inventory.md) for scope. This plan is the
delivery record; update these units rather than creating a competing checklist.
`plans/` is intentionally used because `.gitignore` excludes `/docs/`.

## Outcome and acceptance

Mise owns provisioning, supported packages, config deployment, and managed setup
history. Both a fresh Mac and a Mac using today's dotfiles can reach that state
without losing local configuration or capabilities retained by the user.

Completion requires:

1. `brew` and `stow` are unnecessary for installation, updates, configuration,
   verification, CI provisioning, and the selected plugins/tasks. Native mise
   `brew:` recipes may continue to use `/opt/homebrew`.
2. All baseline packages and tool behaviors have a recorded new owner,
   a verified replacement route, or an explicit user-approved retirement. An
   unsupported package or a skipped required resource blocks completion.
3. Existing installations can transfer ownership with recoverable checkpoints;
   an "installed" cask still owned by Homebrew does not satisfy this requirement.
4. Each machine selects modules and a manual or automatic private-history mode.
   Managed configuration edits and software declarations travel together.
   Automatic machines apply common and enabled-app changes, including package
   installation; manual machines apply on request. Conflicts pause application
   without overwriting unrelated local work.
5. Personal, work, and agent-machine Git identity cases select the expected
   identity and signing configuration in normal repositories and worktrees.
6. Existing safety contracts remain: macOS/non-root checks, prerequisite order,
   explicit drift resolution, identity fallback, secret exclusion, bounded retry,
   and accurate failure status. Dry runs do not mutate the Mac.
7. Applicable behavioral, syntax/static, broader smoke, and migration acceptance
   checks pass. Native bootstrap success alone is insufficient because some
   unsupported/invalid declarations warn or skip.
8. Every backed-up plist is encrypted before its first private-history save.
   Restore covers the actual app configuration, including relevant non-plist
   files. Public sources contain declarations and adapters, not private snapshots.
9. The old profile system and OpenCode integrations are retired. Tests protect
   retained user behavior and data; preserving the old test suite is not a goal.

Planning does not authorize creating the private remote, enrolling credentials,
granting permissions, uninstalling Homebrew, or modifying live Macs.

## Common setup and machine exceptions

Install one common base everywhere: the retained core plus all software formerly
in `cloud`, `dev`, `formatters`, `image`, and `languages`. These names may still
describe cohesive module folders, but no longer select installation profiles.
OrbStack and its Docker setup therefore belong to the common base.

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
  conf.d/
    fish/
      mise.toml                   packages, login shell, files, plugin task
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
      mise.toml                   defaults and native LaunchAgents
      system-settings.sh          only behavior outside native declarations
    orbstack/
      mise.toml                   common on every Mac
    cloud/
      mise.toml                   common cloud tools
    linearmouse/
      mise.toml                   app and encrypted mutable config
    thaw/
      mise.toml
      preferences.sh              capture/restore through app/defaults APIs
    supercmd/
      mise.toml
      preferences.sh
    loopback/
      mise.loopback.toml           selected only on machines that use it
      preferences.sh
    obs/
      mise.obs.toml               app and its required plugin together
    displaylink/
      mise.displaylink.toml       optional driver
    cli/
      mise.toml                   common CLIs without their own module
    apps/
      mise.toml                   common apps without managed config
  tasks/                          shared native operational commands
    sync
    update
    config
  bootstrap/                      first-use and existing-install migration
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

Use `mise.toml` for common setup and `mise.<app>.toml` for an optional capability.
For example, local `env = ["loopback", "obs"]` loads those two modules. This is
mise's module mechanism, not a replacement profile taxonomy. No extra module
index, copied package list, profile aliases, or selection menu is needed. Keep
all optional-only files/services/packages in the optional fragment. Empty local
selection still installs the complete common base. Retire old profile flags and
saved selections with an explicit migration message, not silent reinterpretation.

The active shared payload has the same relative layout under `~/.config/mise`:

```text
~/.config/mise/
  config.toml
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

Use native mise commands and tasks as the operational route. Keep `dotfiles` as
a thin compatibility command for retained operations over that route;
retire the old `cli/`, `config/`, and `maintenance/` implementation layers as their
contracts move. The root repository `mise.toml` does not duplicate machine
resources. Run active bootstrap from a neutral directory and prove same-run tool
resolution before retiring current environment-loading helpers.

| Path category | Runtime owner | How changes travel |
| --- | --- | --- |
| Module manifests and supporting sources | Active `~/.config/mise/conf.d/` | Private history, then common/enabled-app bootstrap |
| Shared operational tasks | Active `~/.config/mise/tasks/` | Private history, then serialized execution |
| Generated machine Git includes | Module templates plus local machine inputs | Shared input changes travel; outputs stay machine-scoped |
| App-written managed regular files | Live file plus private history | Save/sync/pull; no recurring seed overwrite |
| App preference exports | Private encrypted snapshots plus module adapter | Save/sync/pull, then restore only on an eligible app/machine |
| Public baseline and tests | This Git repository | Explicit reviewed import/promotion |
| Local-only preferences and enrollment | Local files/history | Never exchanged by default |
| Credentials and sessions | Existing secret/app owner | Excluded, or explicitly encrypted eligible file |

Do not track the public checkout. Tracking a symlink records its link, not the
source content; explicitly track the shared native payload. Keep real live
directories so applications cannot write runtime data into the module tree.

The supported software-add path records the tool/package/plugin in its owning
module before installation. Shared declarations reach all machines; optional
fragments apply only to machines enabling the app. Explicit machine-only additions
remain local. Preserve version policies and hardware eligibility, not installed
binary copies. Report unmanaged installations for enrollment. These contracts
also apply when an agent changes the setup.

## Delivery order

Each row is a proposed review unit, not a completed task or published PR.
No numeric PR cap was requested. The review budget is one coherent behavior;
split the marked batches when their acceptance decisions become independent.
Line estimates below include implementation, tests, and documentation, measured
as additions plus deletions. They are rough scope estimates based on the current
script/config sizes, not measured diffs; re-estimate after M0 and before execution.

| Unit | Result | Depends on | Estimate and readiness |
| --- | --- | --- | --- |
| M0 | Version, composition, and ownership feasibility report | None | 200-500 lines; ready for isolated work |
| M1 | Safe official mise bootstrap from stock macOS | M0 version/composition gate | 300-700; draft |
| M2 | Common base and per-machine app enrollment | M1 | 200-450; draft |
| M3 | Formula/tool ownership without brew | M0 package gate, M2 | 300-700 per bounded batch; draft |
| M4 | Cask/App Store/vendor app ownership | M0 cask gate, M2 | 300-700 per artifact class; blocked on transfer proof |
| M5 | Native modules and safe file ownership replacing Stow | M1, M2 | 350-750; draft, then small tool batches |
| M6 | Machine Git templates and scoped identities | M5 | 300-650; draft |
| M7 | Fish login shell, activation, plugins | M3 Fish/Fisher, M5 | 250-600; draft |
| M8a | User defaults and appearance LaunchAgent | M5; selected apps for Dock | 300-650; draft |
| M8b | Remaining system and app setup tasks | M8a | 250-600 per cohesive behavior; draft |
| M9 | Remaining tool setup through mise tasks | M3-M5; M7 where Fish-dependent | 150-400 per tool family; draft |
| M10 | Complete setup history, encryption, local enrollment | M2, M5; origin/key inputs for enrollment | 300-700; draft |
| M10a | Encrypted application preferences and safe restore | M10; relevant M4/M5 app owners | 200-450 per distinct storage behavior; draft |
| M10b | Serial exchange and automatic setup application | M0 protocol gate, M10/M10a; relevant setup owners | 300-700; draft |
| M11 | Maintenance and public command migration | M3-M10b relevant owners | 350-750; draft |
| M12 | CI and verification without Homebrew/Stow | M3, M5; ported checks | 250-600; draft |
| M13 | Existing-Mac migration and Homebrew retirement | M0-M12 | 300-700 migration code; rollout separately gated |
| M14 | Fresh/existing acceptance and legacy removal | M13 plus all acceptance evidence | Re-estimate deletion diff; draft |

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
- Prove D10's serial save/sync/pull/bootstrap protocol with two clients, an
  autosaving watcher, local mode overrides, and no second incoming writer. Test
  settled complete source/config revisions, native lock behavior, interrupted
  pull, validation failure, and bootstrap-generated checkpoints without loops.
  Identify usable native status/revision interfaces before implementing a worker.
- Compare a Stow temporary-HOME deployment with mise's target map, including
  tracked files that Stow intentionally excludes and approved retirements. Check
  missing optional apps, source deletions, directories holding runtime state,
  and foreign parent links.
- Build a complete package ledger from the inventory plus a read-only installed
  package inventory on each migration target. Distinguish declared, dependency,
  manually installed, absent, and already mise-owned packages.
- On disposable Macs, prove representative formula adoption/update, cask ownership
  transfer, self-updating app adoption, font/binary artifacts, pkg installation,
  third-party taps, and unsupported-recipe failure. Inspect mise source or a
  documented upstream mechanism before designing any receipt handoff.
- Check the existing sudo broker contract against mise's actual noninteractive
  behavior. A cached sudo timestamp is not assumed sufficient. Do not add
  passwordless sudo policy or run the whole bootstrap as root.
- Verify one encrypted binary/XML plist round trip and one real app's safe
  capture/restore lifecycle before committing to M10a's adapter contract. Local
  path discovery alone does not prove portable contents or successful restoration.

Produce a committed compatibility report and refine later drafts. A successful
metadata dry run does not prove installation, upgrading, TCC preservation, or
receipt ownership. If a gate fails, pause only its dependent work and record the
observed failure and smallest alternative experiment.

## M1: Start without mise, Fish, or Homebrew

Refactor the first-use path in `install.sh`/`bootstrap/`, retaining useful safety
and dry-run flags while retiring profile selection. Run on stock `/bin/bash` 3.2,
regardless of the user's current zsh shell.

Preserve Full Disk Access, Xcode Command Line Tools, and validated sudo ordering.
When CLT is missing, launch Apple's installer interactively and exit for rerun;
automation reports the prerequisite instead of waiting. CLT provides initial
Git/SSH, avoiding mise's possible host-package-manager fallback before cloning.

Install an official mise release into `~/.local/bin`, with a verified pinned
installer or release digest and no `curl | sh` dependency in the trusted path.
Do not require GPG/minisign to exist on a fresh Mac without bootstrapping them.
Keep an existing newer compatible binary; preserve rollback material for an
actual replacement. Explicitly establish PATH for the current run and future
stock-shell sessions. Use only SSH for cloning the dotfiles repository.

Seed the native global files (`config.toml`, `conf.d/`, and `tasks/`), or restore
the existing private setup, without overwriting unknown config. Then invoke the
effective setup. Preserve resumability and do not write the install marker when
a required phase fails. Distinguish a first `--from --dry-run` that only reports
cloning from a full configuration preview.

Acceptance: no-mise/no-brew environment, failed download/checksum, missing CLT,
missing FDA, unavailable sudo, existing config conflict, dirty checkout, rerun
after interruption, and tools available without reopening the shell. Use the
existing bootstrap/environment tests as evidence of retained behavior. Keep only
tests that exercise the new public boundary; discard old call/fixture plumbing.

## M2: Native modules and machine enrollment

Remove the grouped profile model from `bootstrap/profiles.sh`,
`bootstrap/install-options.sh`, and `bootstrap/install-selection.sh`. Install the
common base from D11 on every Mac, including unknown hardware. Optional modules
have one local selection owner and no umbrella presets. Apply the work exclusions
from the inventory; do not reconstruct machine selections from obsolete aliases.

Keep tracked machine data and consume its existing environment interfaces during
transition. Generate only local selection/overrides, preserving unrelated local
mise settings. Model optional modules, Git identities, and full-setup sync mode
separately. Keep mode/origin local; incoming config must not enable automation or
change another machine's optional selection. Read the installed inventory when
migrating existing choices; preserve unknown software.

Acceptance: inspect the real effective configuration for an empty optional list,
the work selection, and one optional audio/app module. All include the common
base; work contains none of its excluded resources; incoming history preserves
local selection and mode. Remove the old profile-menu/alias tests. Both sync
modes use native `history.sync = "manual"`; M10b owns scheduling. Verify that
one-run `-E` replaces the local list so it cannot accidentally widen selection.

## M3-M4: Move package ownership

Use the inventory plus D11's retirements/additions as the completeness baseline.
Preserve current version channels and deliberate trust/cooldown exceptions unless
compatibility requires a reviewed change. Avoid unrelated tool-manager churn
while removing brew.

M3 maps remaining native formulae to `bootstrap.packages` and retains current
`[tools]` declarations except OpenCode. Use canonical names and stable paths for
native libraries and keg-only tools. Replace executable `brew --prefix` lookups
with verified mise package-location queries or declared paths; the prefix can
still be named
`HOMEBREW_PREFIX` during compatibility. Formula receipts can be recognized in
place, but validate dependencies and an actual upgrade with brew unavailable.

M4 maps apps/fonts to `brew-cask:`, enables deliberate adoption, and establishes
receipt ownership before retiring the old manager. Prioritize Slack, Discord,
Zoom, ChatGPT, and T3 Code for self-update and permission checks. Also cover
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

Acceptance per batch: fresh install, existing state, second apply, upgrade,
failure/retry, dependency preservation, running self-updating app, and reported
owner. Validate application launch and selected GUI permissions on an actual
logged-in Mac. Preserve unrelated manually installed software throughout.

## M5: Native modules and safe file deployment

Move each capability into `conf.d/<capability>` and keep its native declarations,
config sources, templates, and necessary tasks together. Remove Stow's synthetic
`config/.config/<tool>` and `config/Library/...` path prefixes. Explicit target
entries preserve the actual destination. Do not copy whole legacy Tool Installers
into new module folders as the default migration.

Use source-relative `[dotfiles]` entries for individual files and `symlink-each`
for real application subtrees. Use groups only where a source tree naturally
shares deployment policy. Exclude manifests, setup scripts, and templates from
recursive app deployment. Compare the new target map with the old Stow result;
source-path identity is not a parity requirement. A Git manifest can check public
seed membership but is not a runtime index for regular active sources.

Track active source contents explicitly. Translate meaningful Stow exclusions,
then retire the Stow control files. Keep ignored legacy Git identity, generated
Fish files and VoiceInk authentication/runtime data excluded. OpenCode sources
are retired under D11; its untracked local data is not a migration input.
Migrate `$DOTFILES` references, canonical agent instruction source links, task
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

Acceptance: retained target parity with Stow, clean second apply, app replacing
a symlink, identical unmanaged file, changed copy/template, foreign parent/link,
source removal, permissions, safe capture, safe discard, and orphan cleanup.
Also test source-content sync behind links, seed/import preservation, and public
promotion without exposing private or local data.
Consolidate useful cases from lifecycle/resolution and owned-key merge tests into
a small real-filesystem suite; do not preserve tests of the retired resolver.

## M6-M9: Preserve machine and tool behavior

**M6, Git:** implement D5 with deterministic templates and explicit identity
inputs, no template `exec()` or secret values. Back up/migrate the entry file while
preserving unrelated keys and canonical include order. Test default/scoped
identity and signing inside/outside the chosen directories, nested paths,
worktrees, paths with spaces, unknown machines, and absent optional signing tools.
Keep Git authorship, SSH account selection, and gh actor selection distinct.
Retain the meaningful Git migration/identity cases, updating their entrypoints.

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
app/container failures distinguishable from invalid declarations. For Dock
layout, preserve today's relative placement/optional-app behavior unless an
exact layout is explicitly chosen. Native `apps` enforces a complete declared
order and requires every referenced app to exist; it is not automatically
equivalent to the current dockutil script.

Move the 10:00/20:00 appearance schedule to a native LaunchAgent only after
matching graphical-login, wake, and idempotency behavior. Retire the exact old
managed label after the new one is verified, without running both. Native agents
use `dev.mise.*` labels and do not cover arbitrary system daemons or every plist
key. Without a graphical session, preserve deferred activation behavior.

**M8b, system tasks:** retain narrow tasks for `scutil`, `pmset`, privileged
software-update defaults, firewall policy, FileVault, effective screen lock,
login items, associations, and other unsupported operations. Preserve independent
step reporting and aggregate failure. Recovery keys remain outside history and
logs. Native preference rollback does not undo these system operations.

**M9, other tools:** use the inventory's installer disposition. Retain setup for
bat caches, Ghostty validation, Neovim/Lazy/Mason, TPack, GH extensions, Skills,
Rust components, completions, OrbStack migration, associations, and VoiceInk.
M10a replaces Thaw's plaintext backup path. Remove OpenCode's integrations and
exclusive dependencies using the inventory's consumer map; preserve unrelated
editor, terminal, and assistant behavior without choosing a replacement assistant.
Call tool-scoped tasks explicitly; never run an old full installer after mise has
taken over its same resources. Keep module tasks beside their sources and shared
operational tasks in native `tasks/`. Use task dependencies and `mise exec` or
resolved paths instead of interactive shell initialization. Test launchd
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
including LinearMouse's JSON after safely replacing its old managed symlink.
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
fields during its migration before enabling automatic restore.

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

Retire `tools/thaw/Thaw.plist`, timestamped plaintext backup output, and the
`thaw-config` implementation after an encrypted restore passes. Redirect the
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
schedule it through native launchd, manual machines run it explicitly. Keep a
single incoming apply owner. Reuse native mise checkpoint/conflict/recovery
semantics rather than writing a new Git synchronization engine.

The cycle waits for settled valid managed inputs, captures eligible app settings,
saves intended changes, checks native conflict/recovery status, syncs and pulls
the complete revision, then rechecks state and runs effective bootstrap for the
local selection when needed.
M10a restores changed app snapshots separately after prerequisite setup succeeds.
Do not force conflict choices or run setup after a partial pull. Serialize with
manual configuration and installation operations. M0 must prove status and lock
interfaces; do not infer success from files appearing in place.

Track a fingerprint of effective setup inputs and local selection, plus pending,
failed, and applied results. Mark applied only after required verification.
Coalesce repeated wakeups; retry failures with bounded backoff. Bootstrap may
create checkpoints, so a changed history commit alone must not retrigger setup
indefinitely. Do not call setup synchronously from `[history.reload]`.

Record software additions in the relevant declaration before local installation.
A failed install leaves declared intent and a visible pending result for retry.
Propagate package/plugin/version changes; locally resolve artifacts according to
platform and version policy. New source/task files must be enrolled together
with the declarations that reference them before publication.

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
pull, or history pull as an incidental software update. Preserve or explicitly
redirect the existing `dotfiles` and Fish commands. Add the declared-software
workflow and explicit full-setup sync command; share the application lock with
M10b. Replace the Thaw-only plaintext backup with M10a's encrypted preference
capture; preserve the useful command without its old storage implementation.

M12 keeps a small behavior suite and useful schemas under `tests/`, exposed
through the repository mise tasks and existing compatibility command. Provision
the toolchain through mise on `macos-26`, port Brewfile/Stow groups to native
declaration/ownership and temporary-HOME deployment checks, and remove formats
verification's `brew --prefix ruby` dependency. Keep CI and local
verification on the same command. Use the GitHub Actions skill when changing CI.
Enforce no duplicate package/file owner and no undocumented required-resource
skip. D12 defines the test budget. Remove obsolete profile/Stow/Brewfile and
OpenCode tests with their owners, exact shell-command snapshots, and helper-level
tests that add no distinct user-visible protection. Validate manifests with native
mise/parsers; do not reproduce mise's package, template, or history internals.

## M13-M14: Existing machines, acceptance, and retirement

M13 provides a report-first migration command. Its journal records original
package owners, config targets/backups, app locations, service labels, and each
completed transfer. It must resume without replaying destructive steps.

1. Inventory and review installed state, dirty public sources, drift, and unknown
   packages. Preserve manually installed extras; undeclared does not mean unused.
2. Install and verify the official mise binary independently of Homebrew.
3. Enroll effective config/modules and required history-owned sources; migrate
   one ownership batch at a time using M0's proven procedures. Do not remove a
   package before its replacement works. Keep automatic application disabled
   until the complete selected setup has transferred and passed acceptance.
4. Check app launches, plugins, Git identities, shell startup, and service state.
5. Run installation, updates, and verification with brew/stow unavailable. A
   missing-PATH check alone is insufficient if scripts call absolute brew paths.
6. Retire the Homebrew executable/manager only after all ownership gates pass.
   Do not run the generic Homebrew uninstaller or remove `/opt/homebrew`, because
   mise-owned bottles and app artifacts can still live there. Review an exact
   path list and backup/restore procedure before the destructive step.

M14 exercises fresh and migrated Macs, both sync modes, the work exclusions, and
encrypted app recovery. Exercise the three Git identity shapes in focused Git
fixtures; do not multiply every package test by every identity and sync mode.
Production completion still requires the applicable target-machine checks.
Package capability changes and missing access remain explicit blockers.

Remove obsolete Stow/Brewfile orchestration and compatibility code only after its
last consumer migrated. Preserve user-authored configuration, public history,
machine records, private-setup boundary, and useful behavioral tests. Update
README, POST_INSTALL, CONTEXT, relevant AGENTS instructions/skills, and ownership
documentation to describe the implemented result. Use the instruction-authoring
skills for guidance changes; do not silently leave contradictory Stow rules.

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
Drop the profile menu/alias matrix. During the Stow transition, compare retained
targets in a temporary HOME with `--no-folding`; remove that compatibility check
when Stow is gone. Continue `fish --no-execute` and tests of affected interactive
versus subprocess behavior, not plugin fixture internals.

M0's compatibility experiments and live migration acceptance are not an exhaustive
CI matrix. Keep package ownership/upgrade, App Store authentication, TCC, login/
wake, and app preference restore in a short macOS acceptance checklist. Run it
for the affected implementation or dependency change; do not download every app
for each docs/config edit. Fakes cannot establish these integration results.

Inspect both `mise bootstrap --dry-run` and component statuses. The declarative
`bootstrap plan` does not cover every bootstrap part; neither preview proves
template results, application permissions, or package ownership transfer.

## Recovery and supported intermediate states

Use expand, migrate, retire: the old route remains usable for resources it still
owns, and the new route operates only its migrated set. Ownership is exclusive
even while both implementations exist. A full old installer must not reclaim
migrated resources. Persist the selected transition state per machine.

Before a transfer, record a recoverable checkpoint and the exact prior target.
For config failures, restore reviewed backups or tracked history and reconcile
owners before retrying. For packages, keep the working installation until the new
owner is verified; a rollback may require vendor reinstall and is not promised
to downgrade an app. For services, stop the failed new label and restore the
known old definition. For system settings, record prior values when feasible and
document operations that need manual recovery.

Mise history undo restores tracked files, not installed packages, macOS privacy
grants, or the full system. Keep its state directory and machine identity intact.
Never rely on history as the only backup of an untracked migration target.

## Readiness and next action

M0 is ready for isolated execution. Later units are draft contracts, with explicit
gates and estimates to refine from M0. D9 closes the sync-coverage decision:
managed configuration and software/setup declarations travel together. Full
production cutover is blocked on verified package/cask transfer, the tested mise
version/global-setup composition and automatic application seams, and
machine-specific enrollment/GUI acceptance. Actual identities, paths, origin,
recipients, and which Macs use automatic sync are collected during enrollment;
none were guessed during planning.

Observed planning evidence is limited to source/documentation inspection and the
isolated mise probes recorded in the decision map. No download/install migration,
two-machine synchronization, TCC preservation, or complete fresh bootstrap was
claimed or tested on a live Mac.
