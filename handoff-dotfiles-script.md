# Specification: Lean Dotfiles Command

Status: implemented. The three cumulative capability boundaries below describe
the shipped command and remain the acceptance contract for future changes.

## Problem Statement

The Dotfiles Repository already has capable owners for bootstrapping macOS,
installing individual tools, validating Brewfiles, updating software, and
backing up application settings. Those capabilities are fragmented across root
scripts, Tool Installers, Fish functions, and helper commands. They are harder
to discover and invoke consistently from a fresh clone, but replacing them with
a second implementation would create more maintenance work than it removes.

The recurring operational problem is narrower. Applications sometimes replace
a Stowed Config symlink with a regular file. The application continues to work,
but its later changes happen only in the live file under the home directory, so
Git no longer observes them. Recovering safely requires identifying the exact
Managed Config Entry, comparing the tracked and live versions, deciding which
one wins, backing up the live state, and restoring Stow ownership without
blindly adopting unrelated runtime or secret data.

The two managed Macs also need different global coding-agent workflows. Common
instructions should remain tracked once, while an optional tracked machine
layer is selected by the existing hardware-hash Machine Config. Claude and
Codex must receive the same effective guidance through the entry points each
product actually discovers.

This repository is operated by one person for two Macs. It needs a small,
predictable management interface and strong safety at the Stow boundary, not a
general-purpose fleet manager, state database, transaction framework, or
policy engine.

## Solution

Add one executable `dotfiles` at the repository root. The `bin` Tool Installer
exposes that same executable as `~/.local/bin/dotfiles`, so a fresh clone can
use `./dotfiles` before installation and every caller shell can use `dotfiles`
after installation.

The root executable is a small dispatcher. It resolves the canonical clone,
validates the complete public grammar, exports the canonical repository root,
and delegates to one capability owner. It does not reproduce Bootstrapper,
Tool Installer, Homebrew, Stow, updater, or application-backup behavior.

The public surface is organized into three cumulative boundaries:

| Phase | Capability | Outcome |
|---|---|---|
| 1 | Dispatcher, Install, Tool Catalog, Verification Suite, and Effective Agent Instructions | One trustworthy entry point and one local/CI verification contract |
| 2 | Config Lifecycle and Agent Resolution Session | Safe inspection and resolution of app-replaced Stow links |
| 3 | Software Maintenance, application Backup, and Fish migration | Thin canonical workflows over the existing updater and backup owners |

### Phase 1 public interface

```text
dotfiles install [--dry-run] [--core-only | --all-profiles | --profile LIST]
                 [--no-upgrade]
dotfiles tool list
dotfiles tool apply <tool>
dotfiles verify
dotfiles help [command path...]
```

`install` preserves `--profile LIST`, `--profile=LIST`, repeatable profiles,
comma-separated profiles, `-n`, `-h`, and the existing long options. It
delegates a valid operational invocation to the Bootstrapper without changing
argument order or meaning. There is no redundant `plan` command; preview is
`dotfiles install --dry-run`.

For a real interactive install, the first user-facing prerequisites are Full
Disk Access, Xcode Command Line Tools, and validated sudo credentials, in that
order. Missing Full Disk Access defaults to exiting before package selection;
missing Command Line Tools starts Apple's installer and exits. Sudo
authentication allows three attempts through one protected per-run
`SUDO_ASKPASS` broker. The credential stays only in broker memory, and helper
requests are serialized so parallel Homebrew casks each receive one complete
response. Package retries revalidate the broker and request the password again
if it stopped.

The Bootstrapper establishes a temporary RiseupVPN Connectivity Rescue before
probing GitHub web, Git, and release-download routes in parallel. The adapter
downloads LEAP's pinned `aarch64` disk image, verifies its checksum, extracts
the native application and lifecycle hook without executing the Intel-only Qt
wrapper, and validates every critical executable as ARM before installation.
Rosetta is never installed or used. The operator then connects without an
account. A pre-existing native installation remains user-owned. A
Bootstrapper-owned installation stays available after a failed run and is
removed with its ARM lifecycle hook only after all networked phases succeed. A
managed WARP rescue left by an earlier Bootstrapper is removed during
migration. Non-interactive execution fails instead of installing or opening a
VPN application.

Each Brewfile first uses `brew bundle install --jobs=auto`. Transient failures
retry the whole idempotent Brewfile, so installed entries are skipped and
unfinished entries retain Bundle-owned dependency handling. The final bounded
retry uses one install job and one download at a time. Homebrew receives five
curl retries per download by default, and the outer Bundle loop makes at most
five attempts with 5, 10, 20, and 30 second waits. Persistent failures are
collected across Brewfiles and block cleanup, Tool Installers, first-run tasks,
Fish setup, and the install marker.

Tool List discovers executable Tool Installers immediately below the tools
root and prints their exact names in stable lexical order. Tool Apply accepts
one discovered name and no additional arguments. It runs the complete Tool
Installer, including any provisioning, service, Stow, or optional-dependency
behavior owned by that installer. It is not a config-only operation and has no
`--dry-run`.

`dotfiles verify` runs the complete deterministic offline Verification Suite.
It never provisions dependencies.

Phase 1 also establishes these Effective Agent Instructions:

- The tracked common source is `tools/ai/AGENTS.md` and the managed common
  destination is `~/.agents/AGENTS.md`.
- The common source instructs agents to read
  `~/.agents/AGENTS_LOCAL.md` when that file exists.
- A Registered Machine may add the optional tracked source
  `machines/<hardware-hash>.agents.md`. Its managed destination is
  `~/.agents/AGENTS_LOCAL.md`.
- Claude reads a managed `~/.claude/CLAUDE.md` whose content imports
  `@~/.agents/AGENTS.md`.
- Codex reads a managed `~/.codex/AGENTS.md` link to
  `~/.agents/AGENTS.md`.
- A non-empty `~/.codex/AGENTS.override.md` is preserved and produces a
  warning because it shadows the managed Codex instructions.

There is no generated or concatenated instruction document. Editing a common
or machine-specific source takes effect immediately through its link. Reapply
the `ai` Tool Installer only when adding or removing a machine-specific source
so that the local link can be created or removed.

### Phase 2 public interface

```text
dotfiles config status [tool]
dotfiles config diff <tool> [path]
dotfiles config repair <tool> [path] [--dry-run]
dotfiles config capture <tool> <path> [--dry-run]
dotfiles config discard <tool> <path> [--dry-run]
dotfiles config resolve <tool> <path> [--agent claude|codex]
```

Config paths are relative to the home directory, for example
`.config/fish/config.fish`. An exact path must identify one eligible Managed
Config Entry. Absolute paths, `~`, parent traversal, empty or ambiguous
normalization, and paths outside the selected Tool Directory are rejected.

The Config Lifecycle always inspects current filesystem and Git state. It does
not depend on an install receipt or a previous observation. Its five states are:

| State | Definition |
|---|---|
| `linked` | The live target is a working symlink to the exact tracked source. |
| `missing` | No filesystem entry exists at the live target. A broken symlink is not missing. |
| `identical` | The live target is a regular file with the same bytes and Git-relevant executable bit as the tracked source. |
| `divergent` | The live target is a regular file whose bytes or Git-relevant executable bit differ from the tracked source. |
| `conflict` | The live target is another symlink, including a broken foreign symlink, or is a directory or special file that cannot be handled mechanically. |

Eligible entries are Git-tracked files below a Tool Directory's Stowed Config.
Discovery respects that package's `.stow-local-ignore`; the ignore control file
itself and untracked runtime state are never Managed Config Entries.

Status and Diff are Inspection Commands. Status without a tool emits one
concise count line for each Tool Directory that owns eligible entries. Status
for one tool reports every non-linked entry and summarizes its linked entries.
Drift is a successful Status result when classification was faithful. Diff
shows the selected tracked/live difference without starting a pager and prints
`No differences` when the valid scope has no differing content. It reports
metadata rather than following a foreign or broken symlink.

Repair is the mechanical Action Command. It restores links only for `missing`
and `identical` entries, is idempotent, and never chooses between divergent
contents. Tool-wide Repair continues through independent entries and returns
nonzero if a requested entry cannot be linked or any divergent/conflicting
entry remains. `--dry-run` performs the same discovery, classification, and
blocking decisions without changing state.

Capture is the explicit decision that the divergent live regular file should
become the tracked source. It requires one exact divergent entry, refuses a
tracked source with staged or unstaged changes, scans the candidate live
content with Gitleaks, creates a simple safety backup, copies content and the
Git-relevant executable bit into the source, and restores the Stow link. It
never stages or commits the result. A Stow failure triggers immediate
best-effort restoration of the pre-operation tracked and live states.

Discard is the explicit decision that the tracked source should replace a
divergent live regular file. It creates the same kind of safety backup before
removing the live file and restoring the Stow link. A Stow failure triggers
immediate best-effort restoration of the live state.

Config safety backups live outside the repository in a unique timestamped
directory below
`${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/config-backups`. They preserve
the selected content, executable intent, and, when applicable, the literal
target of a symlink. No retention policy, manifest, catalog, restore command,
or backup identifier is added. The command prints the absolute backup path so
the operator can recover it manually.

Resolve opens an interactive Agent Resolution Session only for `divergent` or
`conflict` entries whose live target is absent, regular, or a symlink by the
time backup and launch occur. Directory and special-file conflicts remain
manual. The command backs up both tracked and live states, allows a dirty
tracked source, explains that the selected provider may receive sensitive diff
content, obtains explicit consent, and then launches the selected agent from
the repository root:

- Claude always receives `--dangerously-skip-permissions`.
- Codex always receives `--dangerously-bypass-approvals-and-sandbox`.

When both agents exist and `--agent` is absent, prompt for one. When exactly
one exists, select it. When neither exists or an explicitly selected agent is
missing, fail. Resolve requires an interactive terminal and has no unattended
mode.

The agent receives the initial state, tracked path, live path, Git condition,
and diff. Its initial objective is the selected entry, but the operator may
broaden the work during the conversation. The agent may edit files or execute
the appropriate Config Lifecycle command directly; it is not constrained to a
special mutation API.

After the child exits, Resolve reclassifies actual state and shows the resulting
Git diff. It succeeds only when the entry is `linked`. A nonzero agent exit with
a proven final `linked` state succeeds with a warning. Remaining drift returns
nonzero. Resolve never automatically rolls back the session because the agent
may have made other valid changes; it preserves and reports the backup instead.
Gitleaks is deliberately deferred to the normal pre-commit, Verification Suite,
and CI paths.

### Phase 3 public interface

```text
dotfiles update [--ignore-schedule]
dotfiles backup <all|raycast|thaw>
```

Update is the canonical Software Maintenance workflow. It moves the current
Fish-owned updater behavior into a Bash 3.2-compatible owner while preserving
target order, chained-step semantics, schedule gates, live output, independent
failure continuation, and the final summary. It updates installed tools toward
their latest available versions; it does not preserve originally installed
versions, create a version lockfile, reconcile Brewfile membership, synchronize
the Dotfiles Repository, or remove software merely because it is absent from a
Brewfile.

Homebrew remains daily-gated and Mole clean remains weekly-gated. New stamps
live below `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/update` and are
written only after their mutations succeed and before advisory diagnostics.
`--ignore-schedule` bypasses only those two time gates. Legacy stamps below the
old updater namespace are ignored and not migrated.

Backup requires exactly one target. Raycast and Thaw are direct Adapters to the
existing leaf backup commands and preserve their output and status. `all`
preflights both owners, launches them concurrently, waits for both, preserves a
successful sibling's artifact when the other fails, and emits a stable final
summary. Advanced Raycast arguments remain available only through its direct
owner. Backup has no passthrough arguments and no `--dry-run`.

Phase 3 replaces the former Fish functions with interactive abbreviations only:

```fish
abbr -a -- upd 'dotfiles update'
abbr -a -- backup-configs 'dotfiles backup all'
```

The old Update completion is removed. The canonical Dotfiles completion owns
the grammar and dynamic Tool/Config candidates.

## User Stories

### Command discovery and installation

1. As the operator on a freshly formatted Mac, I want to clone the repository and run one root command, so that I can bootstrap the machine without first installing a wrapper.
2. As the operator, I want the same command installed on my user path, so that later maintenance does not depend on my current directory or shell.
3. As the operator, I want the installed command to resolve the active clone through its symlink, so that every delegated owner uses the correct repository.
4. As the operator, I want my current working directory preserved by ordinary delegated commands, so that invoking dotfiles does not unexpectedly move my shell session.
5. As the operator, I want contextual help at every command level, so that I can discover only the capabilities currently installed.
6. As the operator, I want incomplete command groups to show successful help, so that exploration is harmless.
7. As the operator, I want unknown commands, options, extra arguments, tools, targets, and agents rejected before delegation, so that typos cannot trigger a mutating leaf script.
8. As the operator, I want Install to preserve every supported Bootstrapper selection form, so that the new interface does not reduce fresh-machine automation.
9. As the operator, I want Install preview to remain `--dry-run`, so that applying is the concise default and preview is explicit.
10. As the operator, I want Tool List derived from real executable Tool Installers, so that the catalog cannot drift from the repository.
11. As the operator, I want Tool Apply to run the complete existing installer, so that special provisioning and optional-dependency behavior remain owned in one place.
12. As a maintainer, I want direct owner entry points to remain callable, so that advanced and diagnostic workflows are not forced through the dispatcher.

### Verification

13. As a maintainer, I want one repository-owned Verification Suite used locally and in CI, so that the two environments cannot silently validate different things.
14. As a maintainer, I want the default Verification Suite to be complete and offline, so that I can run it quickly and deterministically during normal development.
15. As a maintainer, I want Verification to avoid network access and durable machine state, so that every run is repeatable and safe on a maintained Mac.
16. As a maintainer, I want every missing verification dependency reported in one preflight, so that I can prepare the environment in one pass.
17. As a maintainer, I want independent verification groups to continue after failures, so that one run returns the complete actionable failure set.
18. As a maintainer, I want bounded parallelism with stable replay order, so that verification is fast without producing interleaved, nondeterministic logs.
19. As a maintainer, I want CI to provision one declared Verification Toolchain and invoke the public command, so that workflow YAML does not become a second test runner.
20. As a maintainer, I want repository secret scanning inside the offline suite, so that tracked credentials block both local completion and CI.

### Machine-aware agent instructions

21. As the operator, I want one tracked common instruction source for Claude and Codex, so that shared working preferences remain consistent.
22. As the operator, I want a Registered Machine to add an optional tracked instruction layer, so that different Macs can describe different workflows without copying the common file.
23. As the operator on an unregistered Mac, I want common instructions without a local layer, so that the repository remains usable before registration.
24. As the operator, I want the existing Machine Config hardware hash to select local instructions, so that a second registration mechanism is unnecessary.
25. As the operator, I want source edits to take effect through symlinks, so that Git immediately observes and distributes instruction changes.
26. As the operator, I want unknown regular files and foreign symlinks at instruction destinations preserved, so that installation never overwrites unowned guidance.
27. As the operator, I want a stale known-managed machine link removed when no source applies, so that instructions from a previous registration do not linger.
28. As a Codex user, I want a warning when a global override shadows managed guidance, so that surprising agent behavior is explainable without destroying my override.

### Config inspection and deterministic resolution

29. As the operator, I want Config Status to inspect current Git and filesystem state, so that its answer reflects what applications have actually done.
30. As the operator, I want only Git-tracked Stowed Config entries considered manageable, so that runtime files, caches, databases, sessions, and secrets are not accidentally adopted.
31. As the operator, I want each entry classified into five understandable states, so that mechanical repairs and content decisions remain distinct.
32. As the operator, I want a broken foreign symlink reported as a conflict, so that it is never mistaken for an absent safe target.
33. As the operator, I want tool-wide Status concise and tool-specific Status actionable, so that normal daily checks stay readable.
34. As the operator, I want Config Diff to work without a pager or persistent report, so that I can inspect sensitive changes through normal terminal and Git-like workflows.
35. As the operator, I want mechanical Repair for missing and identical entries, so that app-replaced links can be restored without a content decision.
36. As the operator, I want Repair to preserve divergent and conflicting entries, so that automation never guesses which content wins.
37. As the operator, I want tool-wide Repair to continue through independent entries, so that one conflict does not prevent other safe repairs.
38. As the operator, I want Capture to refuse a dirty tracked source, so that it cannot overwrite work already in progress.
39. As the operator, I want Capture to scan candidate content for secrets before it enters Git-tracked state, so that accidental credential capture is blocked.
40. As the operator, I want executable configuration scripts supported, so that Capture preserves the only permission bit Git tracks.
41. As the operator, I want Capture to leave the source modified but unstaged, so that I retain the normal Git review and commit workflow.
42. As the operator, I want Discard to restore the tracked source after backing up the live file, so that I can reject application changes without losing recovery material.
43. As the operator, I want every deterministic mutation to support `--dry-run`, so that preview and execution reach the same decision without preview creating state.
44. As the operator, I want Stow failure to trigger immediate best-effort restoration, so that a failed relink does not needlessly leave the selected entry worse than before.
45. As the operator, I want Config safety backups outside the repository, so that potentially sensitive recovery material cannot become tracked by proximity.

### Interactive agent resolution

46. As the operator, I want Claude or Codex to help resolve a difficult divergent or conflicting entry, so that the AI performs edits while I guide intent.
47. As the operator, I want explicit provider disclosure before a sensitive diff is sent, so that I control whether local content leaves the machine.
48. As the operator, I want the chosen agent launched without repeated permission prompts, so that the interactive resolution session can work efficiently.
49. As the operator, I want the session to start with the exact paths, state, diff, and Git condition, so that the agent does not have to rediscover the problem.
50. As the operator, I want the agent free to edit directly or invoke lifecycle commands, so that it can choose the clearest valid resolution.
51. As the operator, I want final filesystem state rechecked independently of the agent exit code, so that proven resolution is authoritative.
52. As the operator, I want incomplete sessions left in place with their backup reported, so that valid wider changes are not destroyed by an unsafe automatic rollback.

### Software Maintenance and Backup

53. As the operator, I want one shell-independent Update command, so that Software Maintenance does not require a healthy interactive Fish configuration.
54. As the operator, I want installed tools updated toward current versions rather than their original versions, so that the workflow does not become a lockfile manager.
55. As the operator, I want daily and weekly work skipped on schedule unless explicitly bypassed, so that frequent Update runs remain practical.
56. As the operator, I want a failed target to stop only its dependent chain, so that unrelated maintenance still completes and the summary reports all outcomes.
57. As the operator, I want Update to avoid Brewfile reconciliation and repository synchronization, so that manually installed software and Git work are not removed or rewritten.
58. As the operator, I want direct Raycast and Thaw Backup targets, so that I can run only the application workflow I need.
59. As the operator, I want aggregate Backup to run both independent owners concurrently, so that the slower GUI workflow does not unnecessarily serialize the other backup.
60. As the operator, I want a successful backup preserved when its sibling fails or the aggregate is interrupted, so that completed work is never rolled back ceremonially.
61. As a Fish user, I want familiar `upd` and `backup-configs` shorthand to expand to the canonical commands, so that daily ergonomics survive without retaining duplicate functions.

### Predictability and maintenance

62. As a script author, I want no globally exported interactive policy or automatic pager, so that subprocess behavior remains predictable.
63. As a maintainer, I want direct Adapters to preserve owner output and exit status, so that the dispatcher does not obscure useful failures.
64. As a maintainer, I want coordinators to use stable domain-specific summaries, so that partial success is understandable without inventing a public machine-readable API.
65. As a maintainer, I want signals forwarded and private temporaries cleaned, so that interruption does not leave orphaned children or runner state.
66. As a maintainer, I want each phase's help, completion, documentation, and tests to describe only shipped commands, so that future placeholders cannot be mistaken for working behavior.
67. As a maintainer, I want all new pre-Homebrew shell paths compatible with macOS Bash 3.2, so that fresh-clone bootstrap remains supported.

## Implementation Decisions

### Delivery and ownership

- Preserve the three boundaries as independently understandable capability
  groups. Help, completion, documentation, and tests describe only shipped
  commands.
- Keep one owner for each behavior. The dispatcher owns routing and public
  grammar; the Bootstrapper owns installation selection and effects; Tool
  Installers own their tools; the Verification Runner owns the Verification
  Suite; the Config Lifecycle owner owns Stow-entry classification and
  transitions; the Update owner owns Software Maintenance; and backup leaves
  own application knowledge.
- Existing direct scripts and advanced leaf interfaces remain valid. Adapters
  validate only their public seam and then delegate.
- New shell code that must work before Homebrew is installed is compatible with
  macOS Bash 3.2 and follows the repository's Shared Installer Helpers and Safe
  Bootstrap Convention.

### Dispatcher, help, and completion

- The canonical executable derives the repository root from its own fully
  resolved location, including a chain of symlinks. It replaces an inherited
  repository-root environment value with that canonical root and preserves the
  caller's working directory except when Resolve intentionally starts its agent
  at the repository root.
- Validate the entire public route before running a delegate. A tool name must
  be an exact discovered immediate child with a regular executable installer;
  path separators, traversal, hidden names, symlink escapes, and ambiguous
  entries are not candidates.
- A valid direct Adapter uses process replacement. Its child receives normal
  stdin, stdout, stderr, environment, working directory, exit status, and
  signals without capture or line rewriting.
- `dotfiles`, an incomplete group, contextual `help`, and `-h`/`--help` at any
  level print successful, side-effect-free help. Unknown or excess syntax
  prints an error and relevant usage without invoking a leaf.
- Help and Fish completion use the public grammar as their source of truth.
  Install help/completion reads the Bootstrapper's profile metadata rather than
  hardcoding a second profile list. Completion discovers Tool Catalog names and
  eligible home-relative Config paths only in valid argument positions. It
  never reads live file contents and exposes no completion-generation command
  or CLI aliases. Install keeps `-n` and `-h`; every other operation has only
  the `-h` short option.
- New output uses color only when stdout is a terminal and `NO_COLOR` is unset.
  Color never carries unique meaning.

### Output and failure contract

- Results, plans, progress, summaries, requested help, and diffs go to stdout.
  Warnings, errors, and usage-error help go to stderr.
- New owners return `0` for faithful completion, `1` for incomplete work,
  blocking conflict, or operational failure, `2` for invalid usage, and
  `128 + signal` for interruption. Inspection Commands may return `0` after
  faithfully finding drift; Action Commands return `0` only when their goal is
  achieved or already satisfied.
- Direct single-owner Adapters preserve exact child status, even when it does
  not match the new-owner convention. Tool Apply therefore preserves the
  historical `0` used when an optional dependency is absent.
- Verification, Update, aggregate Backup, and tool-wide Repair continue
  independent units after failure. They return `1` if any critical unit fails
  and print a concise stable-order summary naming failed units and child status
  when available.
- Use domain outcomes: Verification `passed`/`failed`; Update
  `completed`/`skipped`/`warning`/`failed`; Backup
  `completed`/`skipped`/`failed`; Config the five lifecycle states.
- Diagnostics emitted by a new owner carry the narrow public context. Output
  inherited from a leaf is not prefixed line by line.
- A new-owner dry run performs full discovery, validation, classification, and
  decision-making. It prints exact intended changes, creates no backup,
  directory, lock, durable temporary, or other state, and returns nonzero when
  execution would be blocked. Bootstrapper dry-run retains its existing
  contract.
- New modules never start a pager or persist logs, reports, result caches, or
  command history. Persistent state is limited to Update schedule stamps,
  Config safety backups, and application backups created by leaf owners.
- Output prefers repository-relative and home-relative paths. An external
  safety artifact is printed as an absolute path.
- A new diagnostic includes a next command only when it is concrete and safe,
  such as Tool List after an unknown tool or Config Diff/Resolve after
  divergence.

### Verification Runner

- One runner owns check discovery, group membership, order, concurrency, log
  capture, result aggregation, signal handling, and cleanup. CI contains no
  duplicate check inventory.
- The offline graph has nine stable groups in this order: Workflow, Security,
  Shell, Bootstrap, Lua, Fish, Brewfiles, Stow, and Dispatcher.
- Workflow runs workflow lint plus the offline pinned-Action audit. Security
  scans the repository with Gitleaks. Shell performs Bash parsing, ShellCheck,
  and discovered shell behavior tests except the Hammerspoon wrapper. Bootstrap
  runs every supported real Bootstrapper dry-run mode, including a registered
  machine. Lua runs Luacheck and Hammerspoon tests. Fish parses every Fish file
  and runs discovered Fish behavior tests. Brewfiles validates syntax and trust
  metadata for core, every profile, and the Verification Toolchain. Stow
  restows every discovered Stowed Config with `--no-folding` into an isolated
  temporary home. Dispatcher runs the public-contract tests introduced through
  the installed phase.
- Run independent offline groups with at most four workers. Checks inside a
  group remain sequential until an owner establishes another safe boundary.
  Each group captures a private log. Wait for every group, then replay failures
  and print all results in declaration order rather than completion order.
- Preflight every required binary before starting a group. Report all missing
  dependencies together with one instruction to provision the Verification
  Toolchain; never install or silently skip.
- The Verification Toolchain is the mandatory `brewfiles/verification`
  Brewfile included by Core Install and provisioned directly by CI. It declares
  every non-platform binary exercised by the suite. `/bin/bash` and standard
  macOS tools remain explicit platform prerequisites.
- Verification itself does not provision software, add Homebrew taps, modify
  the checkout, or touch the real home. It uses isolated temporary state and
  removes it after success, failure, or interruption.
- Forward `HUP`, `INT`, and `TERM` to every active group, wait for children,
  clean runner-owned state, and return the conventional signal status.

### CI

- CI runs one job on the fixed `macos-26` image for pull requests, pushes to
  the main branch, and manual dispatch. Superseded pull-request runs are
  cancelled; main-branch runs reach a conclusion. The job timeout is 15
  minutes.
- The job checks out the tested ref with a reviewed full-SHA-pinned Action,
  keeps the same-line release comment, and disables persisted credentials.
- The workflow declares no permissions globally and grants only read access to
  repository contents for the job. Pull-request code receives no secrets,
  OIDC, writable token, caches, artifacts, or deployment authority.
- CI provisions the Verification Toolchain Brewfile and invokes
  `./dotfiles verify` with an explicit Bash shell. Every external Action
  remains pinned to a full commit SHA.
- `CI=true` may adjust presentation only. It never changes inventory, severity,
  or result.

### Effective Agent Instructions

- The `ai` Tool Installer owns the common destination, the optional
  machine-local destination, the Codex destination, and the Codex-override
  warning. The Claude Stowed Config continues to own the Claude import file.
  No destination has two owners.
- Common, Claude, Codex, and optional machine-local destinations are separate
  managed entries with one known source each. Installation may create an
  absent destination or repair its own known stale/broken link.
- Preserve and refuse unknown regular files and foreign symlinks at every
  instruction destination. Report the conflict and leave it untouched.
- A machine-local source applies only when the same hash has a tracked Machine
  Config and a tracked agent-instruction source. An unregistered machine, or a
  Registered Machine without the optional source, receives common guidance and
  no local destination.
- When no source applies, remove the local destination only if it is a known
  managed symlink into the machine-instruction namespace. Preserve every other
  entry.
- Preserve the existing meanings of machine name, ID, hostname, installation
  mode/profiles, and machine-owned Git variables. Agent instructions add no
  receipt, reporter, or alternate registration concept and reveal no private
  Git identity.

### Config Lifecycle

- Build the Managed Config Entry catalog from Git-tracked source entries, not
  from the live home. This keeps ownership bounded even when an application has
  created additional runtime files beside managed targets.
- Classification uses filesystem metadata without following a foreign
  symlink. A permission or I/O error that prevents faithful classification is
  an operational failure, not a sixth state.
- Compare regular files by bytes and the executable bit represented by Git.
  Other ownership, timestamps, ACLs, and extended attributes do not create
  Config Drift.
- Status is read-only and succeeds on faithfully reported drift. Tool-wide
  output is concise. A selected tool exposes enough entry detail to choose
  Diff, Repair, Capture, Discard, or Resolve.
- Diff is read-only. It uses Git-style textual comparison when both sides are
  comparable and state metadata for missing or conflicting targets. It never
  follows an unowned symlink or saves the displayed diff.
- Repair calls GNU Stow with the repository's per-file `--no-folding` policy.
  For an identical regular target, keep a private short-lived copy until the
  link is proven, so a failed relink can restore it. No durable Repair backup is
  retained after success.
- Capture and Discard accept one exact divergent regular entry. Linked,
  missing, and identical entries direct the operator to the mechanical path;
  symlink, directory, and special-file conflicts require Resolve or manual
  inspection.
- Capture scans the exact candidate content before changing tracked state. A
  scanner finding or scanner error blocks the operation. Source dirtiness is
  evaluated for the selected tracked entry, including staged, unstaged, and
  type/mode changes.
- Each Capture or Discard backup is a unique timestamped directory that mirrors
  enough tracked and live state to perform immediate best-effort restoration.
  Symlink backups record their literal target and never dereference it.
- Stow is the final owner of the live target. A successful mutation is complete
  only after the target reclassifies as `linked`; otherwise restore what can be
  restored, preserve the safety backup, and return `1`.

### Agent Resolution Session

- Resolve validates interactivity, grammar, eligible entry, state, supported
  filesystem type, and agent availability before creating a backup or starting
  a provider.
- If a provider may receive diff content, display the provider boundary and
  ask for explicit confirmation. Separately display the selected dangerous
  permission-bypass mode, but add no second permission prompt.
- Back up the selected tracked source and live target before launch. Dirty
  source state is valid and included in both the human/agent context and
  backup.
- Initial context is scoped to one entry. The conversation remains an ordinary
  unrestricted agent session, so the operator may authorize wider edits and
  the agent may choose direct file editing.
- Reclassify from disk after the child exits rather than trusting the child
  status or transcript. Print the resulting Git diff and backup location.
- Final `linked` state controls success. Preserve a child failure as a warning
  when final state is linked; preserve all session changes and return `1` when
  it is not.

### Software Maintenance

- Implement Update as a small coordinator plus private target functions. Target
  names are not public subcommands.
- Preserve this target order and behavior:
  1. Homebrew: daily gate; `update`, `upgrade`, `autoremove`, and full cleanup
     form one chain; write the successful stamp, then run Doctor as an advisory
     warning.
  2. mise: upgrade, then prune as one chain.
  3. rustup: update.
  4. App Store: upgrade through `mas`.
  5. Neovim: plugin synchronization, then parser installation as one chain.
  6. Pi: update extensions.
  7. OpenCode: remove its cache when present.
  8. Skills: confirm installed global skills can be listed, then update them;
     inability to list is a warning.
  9. Mole: weekly clean gate and successful stamp.
  10. Fish: update plugins last when Fisher and its manifest are available.
- A failed step stops later steps in the same chain and records the precise
  failed stage. Later independent targets still run. Missing optional commands
  or state are `skipped`, not failures.
- Stream child output live and print one stable summary line per target. Stamp
  failures are target failures. Advisory diagnostics do not invalidate a
  successful mutation stamp.
- Forward signals to the active child, wait, clean coordinator temporaries, and
  retain already completed target work.

### Backup

- Raycast and Thaw direct targets validate public syntax and then process-replace
  their existing backup owners. Their stdout, stderr, GUI interaction, skip
  behavior, and exact status remain unchanged.
- Raycast Backup always uses Raycast's supported export interface through its
  existing owner. It never copies Raycast's plist because that state may
  contain secrets and machine-specific settings that are not faithfully
  portable. Thaw continues to use its existing preference-backup owner.
- Aggregate Backup performs a complete preflight before starting either child.
  A missing owner fails without launching its sibling.
- Run both owners concurrently with labeled start/completion diagnostics and
  live output. Interleaving is acceptable; the final summary is always Thaw
  then Raycast.
- Each owner may receive a private temporary outcome-file location and write
  only `completed` or `skipped`. The coordinator uses child status plus that
  private outcome to distinguish success from an owner-defined no-op without
  parsing human output. This is not a public option or stable data format.
- Wait for both children after ordinary failure. Any missing outcome, malformed
  outcome, or nonzero child is a failed unit. Return `1` if either fails.
- Forward termination signals to both active children, wait for them, remove
  coordinator-owned temporary state, and do not remove application artifacts
  that a child already completed.

### Phase 3 Fish migration

- Remove the updater implementation, backup coordinator function, and updater
  completion from Fish. Keep only the two interactive abbreviations defined by
  this specification.
- Remove the old updater name from internal identifiers, messages, owner files,
  state paths, and completion. Its one intentional remaining occurrence is the
  interactive abbreviation.
- During upgrade, remove only broken symlinks proven to point to the retired
  Fish function or completion sources. Preserve regular files and foreign
  symlinks at those destinations.
- Finish both clean and upgrade installs by restowing all Stowed Config with
  per-file links.

## Testing Decisions

### Test seam and isolation

- Test primarily through the public `dotfiles` executable. Use direct owner
  tests only when they localize behavior richer than routing, such as Config
  transitions, Update chains, agent-session construction, or backup outcomes.
- Every behavioral test uses a fixture repository and temporary `HOME`,
  `XDG_STATE_HOME`, `XDG_DATA_HOME`, `TMPDIR`, and `PATH`. Fake external
  commands record arguments, environment, working directory, output, status,
  and signals. Automated gates do not mutate a real Mac, package manager,
  application, preference domain, agent session, or backup directory.
- Prefer meaningful scenario coverage over a Cartesian failure matrix. Cover
  one test per Config state and transition, each Update chain stage that blocks
  its successor, representative independent failures, and single/double/
  interruption cases for parallel coordinators. There is no numeric coverage
  threshold.
- Existing shell fixture tests for bin helpers, Git migration/identity, Skills,
  Wget, Fish behavior, and Hammerspoon provide the repository's prior art.
  Existing Bootstrapper dry runs and temporary-home Stow checks remain real
  smoke seams inside the shared suite.

### Phase 1 acceptance gate

- Prove root and contextual help, incomplete groups, usage errors, and that
  help never delegates to an argument-ignoring Tool Installer.
- Prove invocation from the repository and installed symlink, multi-link
  canonical self-location, canonical repository-root export, caller working
  directory preservation, exact child stdout/stderr, exact status, and direct
  signal delivery.
- Prove Install validates and forwards short flags, long flags,
  `--profile=LIST`, repeated profiles, comma-separated profiles, and argument
  order. Run the real supported Bootstrapper dry-run matrix, including Core,
  all profiles, selected/aliased profiles, and a hardware-hash fixture.
- Prove Tool List includes only safe executable immediate Tool Installers in
  stable order. Prove Tool Apply rejects empty, unknown, traversal, slash,
  symlink-escape, and extra-argument cases, then delegates to a fake installer
  with exact environment, working directory, streams, and status.
- Prove Verification preflight reports every missing dependency, starts no
  group on preflight failure, enforces four workers, continues independent
  groups, replays logs and summarizes in stable order, cleans temporary state,
  handles signals, and leaves no durable runner state.
- Prove Effective Agent Instructions for common, Claude, Codex, Registered
  Machine, absent optional machine source, unregistered machine, known stale
  local link, broken known-managed link, regular-file conflict, foreign-link
  conflict, and non-empty Codex override. Fake the hardware probe; never use the
  real Mac identity as the test oracle.
- Restow the bin package into a temporary home and prove the installed command
  reaches the repository root from an external working directory without a
  broken link.
- Run parsing and behavior with macOS `/bin/bash` 3.2, applicable ShellCheck,
  the complete offline Verification Suite, one broader smoke outside the
  changed owner, and the repository Completion Gate.

Phase 1 remains complete only while every item above and the shared Verification
Suite pass locally and in CI.

### Phase 2 acceptance gate

- Prove eligibility includes only Git-tracked Stowed Config entries, honors
  package ignore rules, excludes the ignore control file, and handles nested
  paths, spaces, and executable entries.
- Exercise `linked`, `missing`, `identical`, `divergent`, and `conflict`.
  Include a foreign broken symlink and prove it is conflict.
- Reject absolute paths, `~`, parent traversal, normalization ambiguity,
  unknown tools, ineligible entries, and path/tool mismatches before mutation.
- Snapshot fixture state before and after Status and Diff to prove they are
  read-only. Verify agreed summaries and `No differences` behavior.
- Prove Repair is idempotent, handles only missing/identical entries, continues
  independent entries, preserves divergent/conflicting entries, restores an
  identical file after Stow failure, and reports aggregate failure faithfully.
- Prove Capture and Discard create their safety backup before mutation, preserve
  content and executable intent, leave a successful Capture visible to Git,
  and perform best-effort restoration after Stow failure.
- Prove Capture blocks staged, unstaged, mode, or type dirtiness at its selected
  source; blocks Gitleaks findings and scanner errors; and never stages or
  commits.
- For Repair, Capture, and Discard, exercise both successful and blocked
  decisions under `--dry-run` and prove no backup, directory, durable temporary,
  source change, or live-target change occurs.
- Supplement fake-Stow tests with real GNU Stow `--no-folding` behavior in a
  temporary home.
- The public Resolve route must reject noninteractive use before backup or
  launch. Small direct deterministic tests cover agent selection, missing
  agents, exact dangerous flags, provider confirmation ordering, constructed
  context, dirty source, source/live backup, literal symlink backup, final-state
  reclassification, child-error/final-linked success, and incomplete-session
  failure. Do not automate a pseudo-terminal conversation or launch a real
  agent.
- Run the cumulative Verification Suite, one broader smoke, Stowed Config gate,
  secret scan, and repository Completion Gate.

Phase 2 is complete only when the entry can be detected, diffed, mechanically
repaired or explicitly captured/discarded with rollback-on-Stow-failure, and
the deterministic Resolve contract passes without touching a real agent.

### Phase 3 acceptance gate

- Prove Update grammar, target order, daily and weekly gates,
  `--ignore-schedule`, canonical state namespace, ignored legacy stamps, live
  child streams, stable outcomes, and signals using fake commands.
- For Homebrew, mise, and Neovim, fail each chained stage in turn and prove its
  successors do not run while the next independent target does. Prove stamps
  are written only after successful mutations and before advisory diagnostics.
- Prove every optional missing Update dependency is skipped, representative
  independent failures accumulate, warnings do not become failures, and any
  critical failure makes the final aggregate nonzero.
- Prove direct Raycast and Thaw Backup preserve exact arguments, stdout, stderr,
  and child status.
- Prove aggregate Backup completes preflight before launch, uses real process
  concurrency without timing-dependent sleeps, accepts private
  `completed`/`skipped` outcomes, waits after one failure, handles double
  failure and interruption, preserves successful artifacts, cleans temporary
  state, and summarizes in stable order.
- Prove Fish contains only the two agreed interactive abbreviations, the old
  updater and backup functions are absent, old Update completion is absent, and
  canonical Dotfiles completion owns Phase 3 syntax.
- Exercise an upgrade fixture in which only broken known legacy Fish links are
  removed. Preserve regular and foreign-symlink targets. For both clean and
  upgrade fixtures, restow every package with `--no-folding` into a temporary
  home.
- Run every Fish file through syntax validation and its matching behavioral
  tests, then run the cumulative Verification Suite, one broader smoke, Stowed
  Config gate, and repository Completion Gate.

Phase 3 remains complete only while Update and Backup are canonical, their Fish
implementations stay retired, and the shared Verification Suite passes.

### Cross-phase completion

- Gates are cumulative. The current phase includes all behavioral tests and
  Verification groups from earlier phases.
- Update README, contextual help, Fish completion, CI, and agent instructions
  whenever a phase changes their truth. Help and completion expose no future
  commands.
- Search for stale public names and implementations at the relevant phase. By
  final completion there is no `dotfiles.sh`, `dotfiles plan`, public Brew
  group, Fish Update implementation, or old updater state namespace. The
  interactive `upd` abbreviation is the only deliberate old-name occurrence.
- A mandatory unavailable check blocks phase completion. Report the exact
  command and environmental blocker; omit only checks proven inapplicable.
- Complete the repository gate on every implementation session: the narrowest
  behavioral test, applicable syntax/static checks, one broader smoke,
  `git diff --check`, and final-diff inspection. Machine/identity changes add
  Gitleaks and Git-specific checks; Stowed Config changes add the all-package
  temporary-home restow.
- Keep the prepared-machine Verification target below 30 seconds. Measure the
  baseline before changing the four-worker ceiling or group boundaries. CI
  remains hard-limited to 15 minutes. Update and Backup have no timing gate.

## Out of Scope

- A root `dotfiles.sh` compatibility command or a separate `plan` command.
- General `status`, `doctor`, `machine info`, repository diff, macOS diff, or
  public Brewfile command groups. Existing specialized commands remain direct.
- Private Setup. The Dotfiles Command does not inspect, expose, relocate,
  authenticate, update, diagnose, or execute the legacy private installer.
- An Install Receipt, machine enrollment wizard, desired-versus-applied
  database, package history, or software inventory.
- Package uninstall, rollback of Tool Installer/macOS side effects, automatic
  removal of software absent from Brewfiles, or exact-version lockfiles.
- Repository pull/push/synchronization, smart Git reconciliation, automatic
  staging, commits, or publishing.
- Replacing the Bootstrapper, duplicating profile selection, or rewriting every
  Tool Installer behind a new abstraction.
- A Tool Apply preview contract. Tool Installers retain their existing varied
  side effects and optional-dependency semantics.
- Blind or bulk `stow --adopt`, bulk Config Capture/Discard, recursive directory
  adoption, or mutation of untracked live runtime state.
- A config policy language, per-path policy files, validator framework,
  recovery-bundle format, backup manifest, catalog, restore command, retention
  manager, global lock, or transaction framework.
- Automatic resolution of directories or special files and automatic rollback
  of an Agent Resolution Session.
- Gitleaks inside Resolve. Normal pre-commit, Verification, and CI scanning
  remain responsible after an interactive session.
- Real-agent pseudo-terminal automation in the acceptance gate.
- A public JSON API, stable parseable output, private probe commands, persistent
  diagnostic reports, result history, automatic pager, or completion generator.
- Additional Backup targets, Backup passthrough options, Backup dry-run, or
  public Update target subcommands.
- GitHub issues, labels, or remote planning artifacts for this specification.
- Removing existing direct script entry points, except the explicitly retired
  Fish updater/backup functions and their obsolete completion/link artifacts.

## Further Notes

- This specification replaces the previous handoff completely. Earlier command
  proposals such as `dotfiles.sh`, `plan`, `status`, `doctor`, `brew`, and
  `private` are discarded rather than compatibility requirements.
- There are no remaining product or architectural decisions for implementation
  sessions to invent. If implementation reveals a factual impossibility, stop
  and amend this specification explicitly instead of silently broadening the
  command surface or adding infrastructure.
- The central design constraint is proportionality: two personally managed
  Macs justify strong ownership and recovery rules at real risk boundaries,
  while receipts, catalogs, general health dashboards, and transactions would
  add maintenance without solving the reported problems.
- Read executable owners before modifying them. Documentation states intent;
  the current executable path remains the compatibility baseline for every
  preserved direct interface.
- Preserve unrelated and pre-existing worktree changes. Inspect the current
  diff at the start of each phase and never assume a clean checkout.
