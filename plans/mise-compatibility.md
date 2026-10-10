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

- Python compilation; Swift typechecking; TOML/JSON/JSONC/YAML/JavaScript parsing;
  EditorConfig;
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

Earlier execution on 2026-10-10: `/bin/bash
.tmp/mise-implementation/verify-entrypoint.sh` invoked `mise run verify` and exited
with status **0** for implementation `d6f939c`. All four integration tests passed
in **192.017 seconds**; typechecking, parser/static, smoke, secret-scan and diff
checks also passed. The wrapper is local ignored evidence, as is
`.tmp/macos-acceptance/evidence/repository-verify-associations.log`.
Neither is required in a fresh checkout. The maintained command is `mise run verify`.

Additional isolated probes verified the official installer downloading the pinned
release, preserving an older executable, a stable rerun, refusal of a regular
non-executable destination, checksum failure without replacement, and refusal
of a redirected parent. Native retry probes confirmed three failed executions
then a stopped automatic retry; the test advances the local backoff clock rather
than waiting through all intervals. An unavailable local origin stops before
application. An unchanged task with `sources` runs only once across two bootstraps.

The package ownership audit compares the retained baseline with the native module
tables: **161 package declarations, one AutoFirma vendor-installer task, 25 retained
mise tools, no missing retained entry, no duplicate owner, and unchanged retained
tool version requests**. Aliases
are canonicalized (`cpanm` → `cpanminus`, `pkg-config` → `pkgconf`, `libvips` → `vips`).
Per-package VM installation results and outstanding update checks are recorded in
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

## Disposable macOS VM acceptance

On 2026-10-10, Tart **2.40.1** booted a disposable macOS **27.0 arm64** guest
with 4 CPUs and 8 GiB RAM. Its initial 50 GB disk was expanded to 160 GB
after a stopped VM backup; Recovery was preserved and APFS verification passed.
Tart's official release archive matched
SHA-256 `363e2701154a8155cbc1bb6d845430c9b42697d2a186bc49574471ca2877db46`;
macOS code-signature and notarization checks passed. The image was
`ghcr.io/cirruslabs/macos-golden-gate-vanilla@sha256:b78a521145ebef24e9916c0b3999e165bb12b587d11524c5fa3ba4fe7bf79bb9`.

The guest received the tracked archive of `6310358`, the fixes through `d6f939c`,
and a disposable SSH public key. Its host key was obtained through the guest
console and pinned for noninteractive SSH. No operator credentials or private
preferences were copied.
The image has preconfigured login, SSH and passwordless sudo; Gatekeeper was
re-enabled before testing because the supplied image disables it. This is a
software-clean VM, not evidence for an untouched Setup Assistant/security flow.

Observed guest results:

- `command -v brew`, `command -v stow`, and `command -v mise` initially found
  nothing; `xcode-select -p` confirmed that Command Line Tools were absent.
- `/bin/bash install.sh --seed-only` exited 1 with the required CLT message.
- `/bin/bash install.sh --mise-only` installed official mise 2026.10.7 and
  succeeded again on a second run.
- `mise exec python@3 -- python3 --version` installed and ran Python 3.15.0.
  Metadata requests had intermittent timeouts; the command ultimately exited 0.
- `/bin/bash -n install.sh bootstrap/install-mise.sh`, the installer dry-run,
  and compilation of all 11 Python files with the guest's Python 3.15 passed.

After the Apple license step, Command Line Tools were installed: receipt
`27.0.0.0.1788430756`, with working `xcrun clang` and Apple Git 2.54.0.
The full setup then ran twice and correctly returned failure on unmet resources;
it has not completed. The guest retained a pending application record instead
of an applied stamp.

The real run exposed these corrections:

- The sudo preflight now runs `sudo -n /usr/bin/true`. The image permits commands
  without a password, but `sudo -n -v` still fails under its sudo policy.
  `install.sh --seed-only` passed twice after the change.
- Native brew taps need GitHub metadata resolution rather than explicit SSH
  URLs. Removing those overrides installed Terraform 1.16.5 and remindctl 0.3.8
  without Homebrew. At that revision, metadata downloads used HTTPS and actual
  Git operations used SSH. The HTTPS change below supersedes that restriction.
- AutoFirma's cask has a manual installer artifact unsupported by native mise.
  A required `setup:autofirma` task prepares the pinned vendor package, verifies
  its archive checksum and package signature, and fails with an actionable
  instruction until installation is complete. With explicit authorization, the
  GUI license and local certificate trust steps completed in the VM. The
  `es.gob.afirma` receipt reports 1.9.2; `setup:autofirma` passed twice afterward.
- macOS `chsh` asks for an account password even after sudo validation. A small
  pre-user hook reads the native shell declaration and uses existing sudo
  authorization for registration and that command. Native mise retains the
  declaration and status verification. After resetting the guest to Zsh and
  removing its Fish shell registration, native user bootstrap passed twice,
  leaving Fish selected and exactly one `/etc/shells` entry.
- `duti` returned error -50 for TOML and returned success for other extensions
  before macOS consent completed. The first correction used `NSWorkspace` and
  verified the resulting handler. In the VM, `mise -C ~ run setup:zed` changed TOML from
  Cursor to Zed, passed again without a dialog, and all four handlers read back
  as Zed. Rejecting a separate change returned 1. IINA's missing-app check also
  returned 1; its media associations remain untested until its download works.
  The later silent implementation below replaces the prompting setter.

Other observed results:

- Native package status reports **88/88 common formulae and 50/59 common casks
  installed**, plus the separate AutoFirma task. All **25 retained mise tools**
  installed. Optional packages and the App Store Xcode selection were not enabled.
  These counts establish installation, not every application's runtime behavior.
- Native formula smoke commands ran Fish 4.9.3, Git 2.56.0, Terraform 1.16.5 and
  remindctl 0.3.8. Homebrew and Stow executables remained absent.
- Native dotfiles and structured edits applied, including separate default and
  directory-scoped test Git accounts. Real repositories selected the expected
  identities. Application symlinks point to regular active sources.
- Two runs of `mise -C ~ bootstrap --only
  dotfiles,mise-shell-activate,macos-defaults,macos-launchd-agents,services,user --yes`
  passed. Before reboot, status reported 64 applied file declarations, three
  tracked trees, six applied edits and 80 set defaults. After reboot, the history
  watcher was running, appearance agent loaded, and Fish selected. History had
  no pending operations.
  The final status collected from Terminal reported 72 defaults set and eight
  unset (one Mail and seven Safari keys). The previous checks ran through SSH;
  persistence versus privacy/access differences between these execution contexts
  remains unresolved. The final snapshot is not a clean defaults acceptance.
  The appearance agent requested Automation permission after reboot; it was not
  granted, so its GUI behavior remains unverified.
- Fisher installed puffer-fish, autopair and fzf.fish. The bat cache, Node/Python
  setup, Rust stable components and Cursor extensions completed. `gh stack --help`
  passed after extension installation. GitHub account authentication is separate.
  Neovim, tmux and external skill restoration initially failed because their Git
  clones required GitHub SSH credentials. Anonymous HTTPS restoration passed in
  the later test copy described below.
- Zed opened its onboarding window from the VM console; Fish rendered its prompt
  and greeting in Terminal. This does not establish editor language-server or
  signed-in agent behavior.
- A local bare history origin stored the first private fixture as encrypted
  content. A separate isolated home without an age identity failed adoption;
  another home recovered the same fixture using only an independent recovery
  key. Local enrollment files and private age identities were absent from the
  origin's tracked tree. These were disposable keys and data, not user backups.
- NordVPN 10.12.0 failed its vendor postinstall assessment and removed its app.
  The VM initially allowed only App Store applications after Gatekeeper was
  re-enabled. With authorization, the UI was changed to "App Store & Known
  Developers". Gatekeeper remained enabled, but the retry still failed; a reboot
  also left notarized ChatGPT and AutoFirma rejected by `spctl --assess`.
  The underlying assessment failure remains unresolved; checks were not bypassed.
- Lato, Ghostty and IINA downloads timed out; direct IPv4 HTTPS probes also failed
  to connect. Open Sans, Roboto, Roboto Condensed, Roboto Mono and Source Code Pro
  initially failed because Git rewrote their recipe clones to SSH. All five
  installed over HTTPS in the later test copy. macFUSE and Noto Sans passed retries
  after test-harness contention was removed.
- `mise -C ~ run --timeout 2m setup:macos` applied automatic updates, firewall and
  power settings, then exited 1 because FileVault is off. Immediate screen lock
  is also unset. The firewall's signed-app restrictions blocked new SSH sessions;
  remaining checks ran from the VM console. No firewall exception was added.
  The local application record still contains a pending fingerprint and no
  successful applied stamp.

Key guest commands and evidence (paths relative to `.tmp/macos-acceptance/evidence/`):

| Command or operation | Result | Evidence |
| --- | --- | --- |
| `mise -C ~ install --yes` | All 25 retained tools installed | `native-tools-status.json` |
| `mise -C ~ bootstrap packages apply brew-cask:nordvpn --yes` | Exit 1 after approved policy change | `nordvpn-retry.log` |
| `mise -C ~ run --timeout 10m setup:bat ::: setup:node ::: setup:python ::: setup:rustup` | Exit 0 | `setup-tasks-independent.log` |
| `mise -C ~ run setup:zed`, repeated | Both exit 0; independent handler readback agrees | `file-association-regression.log` |
| Native resource bootstrap above, repeated | Both exit 0 | `native-resources-repeat.log` |
| `mise -C ~ bootstrap status --json` | Final resource snapshot | `bootstrap-final-status.json` |
| `mise -C ~ exec python@3 -- python3 ~/.config/mise/conf.d/setup/config.py check` | Exit 0 | `final-state-console.log` |
| Encrypted local-origin recovery | Missing key refused; independent recovery key restored fixture | `native-recovery.log` |

Harness errors are retained in the logs: the first final-state probe used an
unsupported `status --only` flag and the wrong application-state field; the
corrected probe passed in `final-check.log`. A prior resource harness ended with
an invalid history-status command after both successful bootstrap runs. Neither
error is counted as a setup success or a product failure.

Tart's nested virtualization support excludes macOS guests, so this environment
cannot establish OrbStack's container runtime behavior. Hardware and privacy
acceptance also remain separate. Sources:
https://tart.run/quick-start/ and https://tart.run/faq/#nested-virtualization-support

Local VM files, access wrappers and command logs are retained under the ignored
`.tmp/macos-acceptance/` directory. They are not part of a fresh checkout.
The VM was stopped after evidence collection, preserving its disk for another run.

## Silent file associations

The `NSWorkspace` setter can require asynchronous user consent. The user's
stacked dialogs showed why this is unsuitable for unattended setup. API contract:
https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication(at:toopen:completion:)

The helper now merges the requested entries into `LSHandlers` through
CFPreferences, preserving unrelated handlers and preference keys. Dynamic types
such as TOML use a filename-extension entry. A per-user lock serializes concurrent
module tasks. Setup reloads only that user's `lsd`, then checks the effective
handler through `NSWorkspace` in a fresh process. Already correct handlers do not
cause a write or reload. Missing apps, invalid stored data and failed verification
return nonzero; no prompting API or UI automation is used as a fallback.

This preference format is undocumented. Direct preference edits alone did not
change the active handler in the experiment. Both a full restart and reloading the
user's daemon made the requested defaults effective on macOS 27.0. Future macOS
versions require acceptance again; failure leaves setup pending with a sign-out
and retry instruction. Upstream's template approach also describes why modifying
preferences while LaunchServices is running is unreliable:
https://github.com/scriptingosx/LSTemplatePkg

Tests used `dotfiles-associations-023be87`, a disposable copy of the earlier VM
snapshot, with Zed 1.23.2 installed through native mise. The original acceptance
VM's firewall was left unchanged. Gatekeeper remained enabled in the test copy.
All evidence below is local under `.tmp/macos-acceptance/evidence/`:

| Operation | Observed result | Evidence |
| --- | --- | --- |
| Seed preferences without reloading | YAML and shell scripts still opened with TextEdit | `association-silent-seed.log` |
| Restart after the seed | Requested handlers read back as Zed | `association-silent-after-restart.log` |
| Change to TextEdit, then Zed, reloading only user `lsd` | Both changes took effect without consent dialogs | `association-silent-lsd-restart.log`, `association-silent-lsd-zed.log` |
| `mise -C ~ run setup:zed` from four TextEdit associations | Exit 0; independent file-URL lookup selected Zed for JSON, YAML, TOML and shell scripts | `association-silent-acceptance.log` |
| Repeat `setup:zed` | Exit 0; preferences and daemon PID unchanged | `association-silent-acceptance.log` |
| Unrelated PNG/HTTPS handlers and preference marker | Preserved through application and concurrent updates | `association-silent-acceptance.log` |
| Mismatched `--check` and `setup:iina` without IINA | Both exit 1; no preference writes or daemon reload | `association-silent-acceptance.log` |
| Two simultaneous updates to disjoint types | Both exit 0; all four requested associations retained | `association-silent-acceptance.log` |
| Reboot after applying the final helper | `--check` exits 0; independent file-URL lookup still selects Zed for all four extensions; Gatekeeper enabled | `association-silent-persistence.log` |

The VM console showed no association dialogs after these tests. IINA's actual
media associations remain unverified because its application was unavailable.
The test copy was stopped after evidence collection.
The probe scripts and VM disks are ignored local evidence, not repository tests;
the maintained suite still has four integration areas and typechecks the helper.

Repository verification on 2026-10-10 used `/bin/bash
.tmp/mise-implementation/verify-entrypoint.sh`, which invokes `mise run verify`
with isolated mise directories. It exited **0**: all four integration tests passed
in **167.800 seconds**, along with Swift typechecking, parser/static checks, the
shell smoke path, secret scanning and diff checks. Evidence:
`.tmp/macos-acceptance/evidence/repository-verify-silent-associations.log`.
The helper used for both repository and VM checks has SHA-256
`f31b6e12a8f9f39b2965ba6034407dc8dc743d6703df45f629b9de188c056fbb`.

## HTTPS bootstrap and dependency downloads

The later user decision replaces the initial plan's SSH-only bootstrap transport.
The public checkout, Neovim plugins, tmux plugins, external skills and GitHub
extension now use HTTPS. Shared Git defaults no longer rewrite GitHub/GitLab HTTPS
URLs to SSH, and tmux installation and maintenance no longer use a Git wrapper.
Existing SSH repository URLs remain unchanged.

Enrollment, adoption and the serial sync gate accept HTTPS history origins as well
as SSH and local test origins. HTTPS URLs containing credentials, query strings
or fragments are rejected. Private repositories still need an authenticated Git
credential helper or SSH access; this change does not create a private remote or
enroll credentials. Native mise documents both transports and credential helpers:
https://mise.jdx.dev/dotfiles/sync.html#repository-authentication

The disposable `dotfiles-associations-023be87` VM received the updated public
sources. Git credential helpers were disabled for the acceptance process, no
GitHub tokens were supplied, and the host's SSH agent was not forwarded. Native
dotfile deployment passed, then anonymous HTTPS `git ls-remote` succeeded for the
public dotfiles repository, `google/fonts`, all six external skill repositories
and `github/gh-stack`. Evidence is local under `.tmp/macos-acceptance/evidence/`:
`https-acceptance.log`, `https-repositories.log` and `https-source-inputs.json`.

| Guest command or check | Observed result | Evidence |
| --- | --- | --- |
| `mise -C ~ bootstrap packages apply brew-cask:font-open-sans --yes`, repeated separately for Roboto, Roboto Condensed, Roboto Mono and Source Code Pro | All five exit 0; five native cask receipts and ten font files present | `https-results.json`, `https-font-*.log`, `https-readback.json` |
| `mise -C ~ run setup:tmux`, repeated | All four plugins installed; all origins use HTTPS | `https-setup-tmux.log`, `https-tmux-repeat.log`, `https-readback.json` |
| `tpack update all` | Exit 0 for all four plugins | `https-tmux-update.log` |
| `mise -C ~ run setup:skills`, repeated | Eight selected skills from six repositories, plus Playwright skills, installed | `https-setup-skills.log`, `https-skills-repeat.log`, `https-readback.json` |
| `mise -C ~ run --timeout 10m setup:nvim`, repeated after the build correction below | Both exit 0; all 26 Git checkouts use HTTPS and match the lockfile | `https-nvim-repaired.log`, `https-nvim-repeat.log`, `https-readback.json` |
| Neovim component readback | Blink and Telescope native libraries load, all six Mason packages are installed, and all 18 declared Treesitter parsers load | `https-readback.json` |
| `mise -C ~ run setup:gh`, repeated; `gh stack --help` | All exit 0; extension installed anonymously | `https-setup-gh.log`, `https-gh-repeat.log`, `https-readback.json` |
| `gh auth status`; executable and Gatekeeper checks | No GitHub login; Homebrew and Stow absent; assessments enabled | `https-final-state.log` |

This smaller test copy initially lacked CMake and Rust. After native installation
of both declared prerequisites, Neovim returned success but Telescope still lacked
its native library: Lazy restore had not retried the earlier failed build. Setup
and maintenance now explicitly rebuild that plugin and fail if its extension
cannot load. The VM regression removed the generated library from view and omitted
CMake from PATH; the new command correctly returned 1. Restoring the prerequisites
and rerunning setup passed, including independent library, LSP and parser readback.
The rebuild uses Lazy's documented blocking command:
https://lazy.folke.io/usage#-commands
Evidence: `https-readback-before-telescope-fix.json`,
`https-nvim-missing-build.log` and `https-nvim-regression.log`.

The five font results came from this separate test copy, not a completed rerun of
the original 50/59-cask snapshot. An unfiltered package-status probe could not
evaluate the SuperCmd tap without Ruby 3, so it is not counted as successful
status acceptance. A diagnostic `mise exec` without tool selectors also started
the full tool installation and was stopped. Its npm safety checks refused
`2password` because of package age and `@luisurrutia/bird` because of download count;
those restrictions were unchanged in that run. The scoped plugin commands passed
afterward. The VM was stopped after the final checks.

Repository verification ran `/bin/bash
.tmp/mise-implementation/verify-entrypoint.sh` and exited **0**. All four
integration tests passed in **151.066 seconds**, including transport preservation
after native Git configuration deployment and HTTPS origin validation. Parser,
typecheck, static, smoke, secret-scan and diff checks passed. The log is
`repository-verify-https-final.log` in the same evidence directory. The common agent
instruction exception was reviewed locally for bootstrap scope; no paired model
review was run for this supporting instruction edit.

## Three-day release policy and Bird exemption

On 2026-10-10, the same disposable `dotfiles-associations-023be87` VM tested the
shared policy with mise 2026.10.7. These installs used `MISE_YES=1`, closed stdin,
and no CLI `--yes`: the latter also accepts Aube reputation prompts and would
mask the original refusals. No operator configuration was applied.

Before deployment, `mise -C ~ install npm:2password` failed at Aube's separate
30-day package-name gate, and `mise -C ~ install npm:@luisurrutia/bird` failed at
two weekly downloads against a threshold of 1,000. The new native Aube file
sets release and package-name age to 4,320 minutes, rejects dependency resolution
when no candidate satisfies the age, and exempts Bird by name. Bird follows
`latest` with native tool-scoped reputation, trust, build and source exemptions;
its third-party dependencies retain their checks.

| Command or observation | Result |
| --- | --- |
| `mise -C ~ install npm:@luisurrutia/bird`; repeated; `mise -C ~ exec node npm:@luisurrutia/bird -- bird --version` | Installed 1.0.0 without accepting reputation prompts; repeat and executable passed |
| `mise -C ~ latest npm:prettier`; `mise -C ~ install npm:prettier@latest`; executable version | Selected and installed 3.9.9; registry latest 3.9.10 was published on the test date |
| `mise -C ~ latest npm:pnpm` | Selected 12.10.1, published October 6; skipped newer October 9–10 releases |
| `mise -C ~ latest` for `npm:2password`, `npm:typescript`, `npm:eslint` | Selected the newest stable release at least three days old in each registry snapshot |
| `MISE_MINIMUM_RELEASE_AGE=100y mise -C ~ latest npm:@luisurrutia/bird`; same probe for Prettier | Bird still resolved 1.0.0; Prettier returned no eligible version |
| `mise -C ~ run setup:node`, repeated; npm, pnpm and Yarn config readback | Three days: npm `3`, pnpm and Yarn `4320` |
| pnpm readback with and without `XDG_CONFIG_HOME` | Both returned `4320`; the macOS native path now links to the same managed source |
| Bird's generated Aube project and manifest | Named reputation/trust/source exceptions and build approval present |

`2password` now passes age selection, but an install without CLI `--yes` still
fails a different reputation gate: 917 weekly downloads against 1,000. No
reputation exemption was added for that third-party package. This remains a
separate acceptance limit, not a release-age failure.

Evidence is retained locally under `.tmp/macos-acceptance/evidence/`:
`package-policy-before-*.log`, `package-policy-install.log`,
`package-policy-resolution.json`, `package-policy-registry.json`,
`package-policy-install-results.json`, `package-policy-pnpm-path.log`, and
`package-policy-aube-readback.json`. These ignored artifacts are not part of the
public seed. The probes use live registries rather than a permanent test of
mise's resolver internals.

The final `/bin/bash .tmp/mise-implementation/verify-entrypoint.sh` run exited
**0**, including all four integration tests in **150.123 seconds**, parsers,
static checks, shell smoke, secret scanning and diff checks. Its log is
`repository-verify-package-policy-final.log`. The VM was stopped after testing.

## Outstanding acceptance

The fresh-Mac exercise in [POST_INSTALL.md](../POST_INSTALL.md) is in progress.
The following acceptance is still outstanding:

- The four remaining common casks (NordVPN, Ghostty, IINA and Lato), optional
  packages, App Store installation, full package updates and driver operation.
- The remaining `2password` download-count refusal without explicit prompt
  acceptance, and complete native package status with the custom-tap evaluator.
- An untouched Setup Assistant/security flow, FileVault and immediate screen lock,
  the eight Mail/Safari defaults reported unset from Terminal, and actual launchd
  GUI behavior after required privacy approvals.
- Real capture/restore/reopen for all six apps, hardware routing and sessions,
  helper-process consistency, and recovery of real settings on another machine.
- Cask self-update and macOS privacy behavior after an actual app replacement.
- Automatic scheduling and real package exchange on a second machine. Two-client
  isolated integration tests pass; this VM used manual sync and a local origin.
- Hosted CI execution, Ubuntu/Arch setup, or a non-arm64 full installation.

An isolated package dry-run still sees the operator's existing prefix and failed
on an old ChatGPT Caskroom receipt. That is not fresh-install evidence; the prefix
was not repaired or changed. Self-updating casks reduce replacement, but replacement
can still reset privacy grants:
https://mise.jdx.dev/bootstrap/packages/brew-cask.html#macos-privacy-permissions

No operator preferences were backed up, real private origin created, user
credentials copied, or setup applied to the operator's Mac. Keep wanted old
settings independently before erase.

References:

- https://mise.jdx.dev/bootstrap/modules.html
- https://mise.jdx.dev/dotfiles/managed.html
- https://mise.jdx.dev/dotfiles/edits.html
- https://mise.jdx.dev/dotfiles/history.html
- https://mise.jdx.dev/dotfiles/encryption.html
- https://mise.jdx.dev/dotfiles/sync.html
