# Migrate the macOS dotfiles repository to mise

Status: planning only; full setup synchronization confirmed in D9. No
implementation or machine migration has started.
Updated: 2026-10-10. Baseline: `0c2f8fe3739a1e16e80d07d476453bf119db55dc`.

Read the [decision map](mise-migration-decisions.md) for authority and tradeoffs,
and the [inventory](mise-migration-inventory.md) for scope. This plan is the
delivery record; update these units rather than creating a competing checklist.
`plans/` is intentionally used because `.gitignore` excludes `/docs/`.

## Outcome and acceptance

Mise owns provisioning, supported packages, config deployment, and managed setup
history. Both a fresh Mac and a Mac using today's dotfiles can reach that state
without losing local configuration or installed capabilities.

Completion requires:

1. `brew` and `stow` are unnecessary for installation, updates, configuration,
   verification, CI provisioning, and the selected plugins/tasks. Native mise
   `brew:` recipes may continue to use `/opt/homebrew`.
2. All current core/profile packages and tool behaviors have a recorded new owner,
   a verified replacement route, or an explicit user-approved retirement. An
   unsupported package or a skipped required resource blocks completion.
3. Existing installations can transfer ownership with recoverable checkpoints;
   an "installed" cask still owned by Homebrew does not satisfy this requirement.
4. Each machine selects modules and a manual or automatic private-history mode.
   Managed configuration edits and software declarations travel together.
   Automatic machines apply matching shared/profile changes, including package
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

Planning does not authorize creating the private remote, enrolling credentials,
granting permissions, uninstalling Homebrew, or modifying live Macs.

## Proposed structure and ownership

The public repository distributes a reviewed baseline; private mise history owns
the enrolled user's effective setup. Preserve current tool paths where useful,
but change their runtime owner. Proposed locations are not present yet:

```text
Public repository
  mise.toml                         enrollment entrypoint
  tools/<tool>/config/              public seeds and reviewed shared defaults
  tools/mise/config/.config/mise/   baseline global setup/modules/history
  machines/<hardware-hash>.sh       public records during compatibility
  bootstrap/                       first-use/enrollment/migration safeguards
  config/                          safe status/diff/capture/discard adapter
  maintenance/                     explicit software maintenance
  verification/                    shared offline verification

Enrolled home (private history owns shared contents)
  ~/.config/mise/config.toml        effective tools and bootstrap declarations
  ~/.config/mise/config.<profile>.toml native optional profiles
  ~/.config/mise/conf.d/            native fragments when needed
  ~/.local/share/dotfiles/setup/    config sources, templates, and setup tasks
  managed live configuration       tracked regular files or per-file links

Local enrollment state (not exchanged)
  ~/.config/mise/miserc.local.toml  environment selection
  ~/.config/mise/config.local.toml origin/mode and local overrides
  machine identity and generated outputs with explicit local/variant policy
```

Use native modules and dotfile groups for different purposes: a module selects
packages/config/services together; a group deploys a source tree. Preserve core,
all, and selected profiles, their aliases, per-package/language choices, and
interrupted-selection recovery. Establish one selection authority and translate
it to native environments; do not maintain Brewfiles and TOML as competing lists.

Keep `dotfiles` as the stable public entrypoint while its implementations become
small mise adapters. Native commands remain available, with their lower-level
overwrite semantics documented. Seed missing effective files at first enrollment;
restore existing private setup through adoption on subsequent Macs. Run ongoing
setup from a neutral directory with effective global config, so the public
project cannot override synchronized declarations. Test same-run tool resolution
before retiring `load_mise_environment` or its equivalent.

| Path category | Runtime owner | How changes travel |
| --- | --- | --- |
| Effective tool/package/modules/tasks | Global mise setup and history-owned sources | Private history, then profile-specific bootstrap |
| Shared Fish/editor/Starship and other managed sources | History-owned source tree or regular live file | Private history; linked source contents explicitly tracked |
| Templates and owned-key merge sources | History-owned source tree | Private history, then render/merge locally |
| Generated machine Git includes | Templates plus local machine inputs | Shared input changes travel; outputs stay machine-scoped |
| App-written managed regular files | Live file plus private history | Save/sync/pull; no recurring seed overwrite |
| Public baseline and tests | This Git repository | Explicit reviewed import/promotion |
| Local-only preferences and enrollment | Local files/history | Never exchanged by default |
| Credentials and sessions | Existing secret/app owner | Excluded, or explicitly encrypted eligible file |

Do not track the whole public checkout. Tracking a symlink records the link, not
its target contents. Track portable source contents separately and retain normal
live directories for runtime data. Do not render all machines' Git identities
into one shared output. Later public imports must diff/merge with effective setup;
an old public seed must never overwrite newer private changes.

The supported software-add path records the tool/package/plugin and its scope
before installing it. Shared declarations reach all machines; profile declarations
apply only to selected profiles. Explicit machine-only additions remain local.
Preserve version policies and hardware eligibility, not installed binary copies.
Unmanaged installation is reported for enrollment, not silently discovered and
published. These contracts also apply when an agent changes the setup.

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
| M2 | Native profile and machine enrollment | M1 | 300-700; draft |
| M3 | Formula/tool ownership without brew | M0 package gate, M2 | 300-700 per bounded batch; draft |
| M4 | Cask/App Store/vendor app ownership | M0 cask gate, M2 | 300-700 per artifact class; blocked on transfer proof |
| M5 | Safe config groups replacing Stow | M1, M2 | 350-750; draft, then small tool batches |
| M6 | Machine Git templates and scoped identities | M5 | 300-650; draft |
| M7 | Fish login shell, activation, plugins | M3 Fish/Fisher, M5 | 250-600; draft |
| M8a | User defaults and appearance LaunchAgent | M5; selected apps for Dock | 300-650; draft |
| M8b | Remaining system and app setup tasks | M8a | 250-600 per cohesive behavior; draft |
| M9 | Remaining tool setup through mise tasks | M3-M5; M7 where Fish-dependent | 150-400 per tool family; draft |
| M10 | Complete setup history, encryption, local enrollment | M2, M5; origin/key inputs for enrollment | 300-700; draft |
| M10b | Serial exchange and automatic setup application | M0 protocol gate, M10; relevant setup owners | 300-700; draft |
| M11 | Maintenance and public command migration | M3-M10b relevant owners | 350-750; draft |
| M12 | CI and verification without Homebrew/Stow | M3, M5; ported checks | 250-600; draft |
| M13 | Existing-Mac migration and Homebrew retirement | M0-M12 | 300-700 migration code; rollout separately gated |
| M14 | Fresh/existing acceptance and legacy removal | M13 plus all acceptance evidence | Re-estimate deletion diff; draft |

M3/M4 and M6-M10b need not form one linear PR stack. Dependencies name required
capabilities; changes to shared entrypoints require coordination, not artificial
functional dependencies. Every unit carries its own tests. Do not detach tests or
hide bulk removals merely to meet the estimated review size.

## M0: Prove the consequential seams

Use disposable HOME/XDG trees and disposable macOS environments for system work.
Never use the operator's live app directory or history origin for a probe.

- Select an official mise release that supports the used schemas and has passed
  the repo's release cooldown. Record version, architecture, release date, and
  verified download digest. Set the eventual `min_version` from evidence.
  Installed mise is 2026.10.1; current documentation includes newer behavior.
  `mise vars --json`, for example, was unavailable in the installed build.
- Prove D3's first-use regular global-config enrollment, later private adoption,
  global module/profile precedence, all-group selection, history visibility,
  same-run runtime availability, and single hook execution. Public seed reruns
  must preserve private edits. Verify paths across different home/account names;
  relative group roots and relative entry sources resolve differently.
- Prove D10's serial save/sync/pull/bootstrap protocol with two clients, an
  autosaving watcher, local mode overrides, and no second incoming writer. Test
  settled complete source/config revisions, native lock behavior, interrupted
  pull, validation failure, and bootstrap-generated checkpoints without loops.
  Identify usable native status/revision interfaces before implementing a worker.
- Compare a Stow temporary-HOME deployment with mise's target map, including
  tracked files that Stow intentionally excludes. Test missing optional apps,
  source deletions, directories holding runtime state, and foreign parent links.
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

Produce a committed compatibility report and refine later drafts. A successful
metadata dry run does not prove installation, upgrading, TCC preservation, or
receipt ownership. If a gate fails, pause only its dependent work and record the
observed failure and smallest alternative experiment.

## M1: Start without mise, Fish, or Homebrew

Refactor the first-use path in `install.sh`/`bootstrap/` while retaining its public
flags. Run on stock `/bin/bash` 3.2, regardless of the user's current zsh shell.

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

Seed regular effective global mise config and required sources, or restore the
existing private setup, without overwriting unknown configuration; then invoke
the effective setup. Preserve resumability and do not write the install marker
when a required phase fails. Distinguish a first
`--from --dry-run` that only reports cloning from a full configuration preview.

Acceptance: no-mise/no-brew environment, failed download/checksum, missing CLT,
missing FDA, unavailable sudo, existing config conflict, dirty checkout, rerun
after interruption, and tools available without reopening the shell. Extend
`verification/tests/bootstrap.sh`, `verification/tests/github-preflight.sh`, and
`tools/mise/tests/environment.sh` rather than duplicating their contracts.

## M2: Native modules and machine enrollment

Translate all ten profiles and current selection/recovery behavior from
`bootstrap/profiles.sh`, `bootstrap/install-options.sh`, and
`bootstrap/install-selection.sh`. Keep unknown-machine core installation usable.
Preserve explicit flags over saved recovery over machine defaults.

Keep tracked machine data and consume its existing environment interfaces during
transition. Generate only local selection/overrides, preserving unrelated local
mise settings. Model role, module list, optional package choices, Git identities,
and full-setup sync mode separately. Keep mode/origin local; incoming config must
not enable automation or switch profiles on a manual machine. Do not assign real
machines guessed roles.

Acceptance: the existing selection tests plus equivalent effective-config checks
for core/all/subsets/aliases, individual package choices, unknown hardware,
invalid saved selections, work/personal/agent roles, and local manual/automatic
operation. Both use native `history.sync = "manual"`; M10b owns scheduling.
Verify `-E` replaces rather than adds to the default environment list.

## M3-M4: Move package ownership

Use the inventory as a completeness baseline. Preserve current version channels
and deliberate trust/cooldown exceptions unless compatibility requires a reviewed
change. Avoid unrelated tool-manager churn while removing brew.

M3 maps remaining native formulae to `bootstrap.packages` and retains current
`[tools]` declarations. Use canonical names and stable paths for native libraries
and keg-only tools. Replace executable `brew --prefix` lookups with verified mise
package-location queries or declared paths; the prefix can still be named
`HOMEBREW_PREFIX` during compatibility. Formula receipts can be recognized in
place, but validate dependencies and an actual upgrade with brew unavailable.

M4 maps apps/fonts to `brew-cask:`, enables deliberate adoption, and establishes
receipt ownership before retiring the old manager. Prioritize Slack, Discord,
Zoom, ChatGPT, and T3 Code for self-update and permission checks. Also cover
macFUSE/sshfs, DisplayLink, VPN/security apps, OBS plugins, and third-party taps.
Record unsupported artifacts instead of treating skipped entries as success.

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

## M5: Replace Stow with safe groups

Declare one group per eligible history-owned config tree using `symlink-each`,
portable links, explicit membership, and translated exclusions. Use the public
Git manifest to check seed parity, not as a runtime index for regular private
source files. Git membership alone misses intentional Stow exclusions. Track
source contents explicitly; exclude Stow control files themselves. Do not include
ignored legacy Git identity, generated Fish files, OpenCode state, or VoiceInk
authentication/runtime data.

Reuse `config/run.sh`'s public inspection and explicit capture/discard semantics.
Before applying, check the complete selected target set, ancestor symlinks,
foreign links, changed regular files, type conflicts, and duplicate owners.
Back up before a reviewed transition; no automatic adopt, force, or deletion.
Keep inspection success distinct from mutation success.

Use structured merge entries for the Codex settings currently merged by awk,
preserving plugins and other unrelated keys. Evaluate Claude settings the same
way. JSONC is not supported by native merge: retain a suitable whole-file owner
or a format-aware task for Zed and other comment-bearing formats.

Acceptance: equivalent target inventory to Stow, clean second apply, app replacing
a symlink, identical unmanaged file, changed copy/template, foreign parent/link,
source removal, permissions, safe capture, safe discard, and orphan cleanup.
Also test source-content sync behind links, seed/import preservation, and public
promotion without exposing private or local data.
Extend `config/tests/lifecycle.sh`, `config/tests/resolve.sh`,
`tools/codex/tests/install.sh`, and `tools/claude/tests/install.sh`.

## M6-M9: Preserve machine and tool behavior

**M6, Git:** implement D5 with deterministic templates and explicit identity
inputs, no template `exec()` or secret values. Back up/migrate the entry file while
preserving unrelated keys and canonical include order. Test default/scoped
identity and signing inside/outside the chosen directories, nested paths,
worktrees, paths with spaces, unknown machines, and absent optional signing tools.
Keep Git authorship, SSH account selection, and gh actor selection distinct.
Extend the existing Git migration/identity tests.

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
Rust components, completions, OrbStack migration, associations, Thaw, and VoiceInk.
Call tool-scoped tasks explicitly; never run an old full installer after mise has
taken over its same resources. Use task dependencies and `mise exec`/resolved
paths instead of interactive shell initialization. Test launchd environments
separately from shell PATH. Keep command wrappers from `tools/bin` functional.

## M10: Complete setup history and private enrollment

Create an allowlisted global history policy covering effective configuration,
all managed shared sources, package/tool declarations, plugin manifests, templates,
and required setup code. Keep public checkout files outside history's write
ownership. Track regular live files or source contents behind links; seed only
when absent. Versioned public import/promotion uses explicit diff/merge.

Keep origin, mode, local profile selection, auth references, and application
stamps local. Use machine variants for suitable nonsecret hardware-specific state,
with stable identity recovery after reinstall. Preserve tracked public machine
records while keeping their generated private/local enrollment outputs distinct.

Configure encryption before the first save of eligible sensitive files. Use
dummy values to prove ciphertext storage, authorized restore, missing-key failure,
recipient changes, and independent recovery. Keep age identities, sessions,
tokens, databases, logs, and caches excluded. Do not combine machine variants
with encryption or assume an SSH agent can decrypt age history.

Use mise's native watcher for local autosave. Set native `history.sync = "manual"`
in local policy on both machine modes; M10b schedules explicit native exchange
and subsequent setup only on automatic machines. Verify background SSH access
without secrets in LaunchAgent environment or incidental authentication changes.
Enrollment needs the actual private origin and key references.

Acceptance: two isolated clients and a temporary Git origin demonstrate changes
in both directions, source/config restoration together, simultaneous edits,
unsaved changes, interrupted pull/recover, undo, and preserved local selection.
Verify local autosave alone neither exchanges nor installs. Local-path transport
is only a test fixture; real-origin acceptance uses SSH. Repeat bootstrap and
public enrollment without reverting synchronized files. Existing lifecycle tests
do not replace dedicated history integration tests.

## M10b: Apply synchronized software and setup

Expose one serial exchange/application command for both modes; automatic machines
schedule it through native launchd, manual machines run it explicitly. Keep a
single incoming apply owner. Reuse native mise checkpoint/conflict/recovery
semantics rather than writing a new Git synchronization engine.

The cycle waits for settled valid managed inputs, saves intended changes, checks
native conflict/recovery status, syncs and pulls the complete revision, then
rechecks state and runs effective bootstrap for the local selection when needed.
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

Acceptance: exchange a Fish/Starship edit, a shared package addition, a selected
profile package, and a manifest plus new task/source between clients. Verify
matching automatic receivers apply them, other profiles remain unchanged, and
manual receivers install only after explicit exchange/application. Also cover
invalid config, conflicts, edits during a cycle, offline/auth failures, failed
installation and resume, permission prerequisites, interrupted restore, duplicate
wakeups, and self-generated checkpoint loops. Prove actual received package
installation on a disposable Mac; fake executables cannot establish that result.

## M11-M12: Daily operations and verification

M11 changes `maintenance/update.sh` to the new owners: official mise self-update,
versioned tool upgrades, native package upgrades, App Store and existing plugin
maintenance. Preserve scheduling gates, independent error reporting, successful
mutation stamps, and `--ignore-schedule`. Do not run global prune, repository
pull, or history pull as an incidental software update. Preserve or explicitly
redirect the existing `dotfiles` and Fish commands. Add the declared-software
workflow and explicit full-setup sync command; share the application lock with
M10b. Keep Thaw backup behavior.

M12 provisions verification through mise on `macos-26`, ports the Brewfile and
Stow groups to declaration/ownership and temporary-HOME deployment checks, and
removes formats verification's `brew --prefix ruby` dependency. Keep CI and local
verification on the same command. Use the GitHub Actions skill when changing CI.
Enforce no duplicate package/file owner and no undocumented required-resource
skip. Reuse existing test suites as behavior evidence, replacing only assertions
that specifically encode a retired implementation.

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

M14 exercises fresh and migrated Macs for all three role shapes and both sync
modes, including cross-machine software installation and private setup recovery.
Actual machine enrollment can be separate from synthetic role coverage,
but production completion requires the target-machine checks. Package capability
changes and missing access remain explicit blockers.

Remove obsolete Stow/Brewfile orchestration and compatibility code only after its
last consumer migrated. Preserve user-authored configuration, public history,
machine records, private-setup boundary, and useful behavioral tests. Update
README, POST_INSTALL, CONTEXT, relevant AGENTS instructions/skills, and ownership
documentation to describe the implemented result. Use the instruction-authoring
skills for guidance changes; do not silently leave contradictory Stow rules.

## Verification contract

There is no application compilation step. The build-equivalent gate is the
repository's syntax/static/config validation, plus the shared Verification Suite.
Run the narrow tests for each changed owner, the applicable CI checks, one broader
smoke path, and `git diff --check`. Record exact commands and outcomes per unit.

Existing commands to retain or deliberately port include:

```sh
./dotfiles verify
bash config/tests/lifecycle.sh
bash config/tests/resolve.sh
bash tools/mise/tests/install.sh
bash tools/mise/tests/environment.sh
bash tools/git/tests/identity.sh
bash tools/git/tests/migrate-config.sh
bash maintenance/tests/update.sh
bash tools/fish/tests/upd.sh
```

For Bootstrapper/Profile changes, preserve all Bash 3.2 dry-run modes listed in
`verification/groups/bootstrap.sh`. For each config migration, restow all still
Stow-owned packages into temporary HOME with `--no-folding` and compare migrated
targets with native mise deployment. Run `fish --no-execute` for every Fish file
and matching Bash tests after Fish changes. Git/machine changes also require the
minimum Git-area syntax/ShellCheck/config checks in AGENTS.md and secret scanning.

Add checks at the owning seam: fresh bootstrap/global enrollment, config safety,
scoped Git identities, package/cask transfer, two-client history, and serial
automatic setup application. Keep package downloads, App Store authentication,
TCC prompts, login/wake, and real app launches in a separate macOS integration
acceptance path. Fakes cannot prove those.

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
