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
- A focused Ghostty download parser check for the exact cask checksum, cache
  integrity, and rejection of directories, links, truncation and extra payloads.
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
  The effective rules were not verified during that attempt. The later
  [Gatekeeper recheck](#gatekeeper-resolution-and-vm-limits) resolved the failure
  in the test copy without bypassing assessment.
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

At this stage, `2password` passed age selection, but an install without CLI
`--yes` still failed a different reputation gate: 917 weekly downloads against
1,000. That separate refusal was resolved in the follow-up below.

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

### 2password download-count exception

The user then approved a named `allow_low_downloads = true` exception for
`npm:2password`. Aube groups download count, new package names and similar-name
checks under this option. The three-day release cooldown, dependency checks,
trust policy and script policy remain in force.

The same VM reproduced the download-count refusal before copying the changed
manifest. `mise -C ~ install npm:2password` then installed **0.2.0**, and a repeat
passed without reinstalling. Both calls used closed stdin and no CLI `--yes`.
`mise -C ~ exec bun node npm:2password -- 2password --version` and `--help`
passed, as did the Bird version smoke check. The generated Aube config contained
only `allowedUnpopularPackages = ["2password"]` and `minimumReleaseAge = 4320`.
With a temporary `MISE_MINIMUM_RELEASE_AGE=100y`, native resolution returned no
eligible 2password release, confirming that the age filter remains active.
No vault access or credentials were needed.

Local evidence: `2password-policy-results.json`, `2password-policy-readback.json`
and `2password-policy-*.log` under `.tmp/macos-acceptance/evidence/`.
`/bin/bash .tmp/mise-implementation/verify-entrypoint.sh` exited **0**: all four
integration tests passed in **154.895 seconds**, along with static, smoke,
secret-scan and diff checks. See `repository-verify-2password-policy.log`.
The VM was stopped after verification.

## IINA download mirror and Lato comparison

On 2026-10-10, IINA's official GitHub release downloaded successfully. Its
SHA-256, `8fad50479b10e09645053457cec46bd53d054ced2242cfe68f74586735a20dc7`,
matches the native 1.5.0 cask. A module-scoped `settings.url_replacements` rule
now maps the vendor DMG URL to that version's GitHub release, retaining native
cask ownership and checksum verification without pinning a separate installer.

In `dotfiles-associations-023be87`, `mise -C ~ bootstrap packages apply
brew-cask:iina` downloaded the GitHub asset and installed 1.5.0; a repeat exited
0 without reinstalling. `mise -C ~ run --timeout 2m setup:iina` passed repeatedly,
as did `/opt/homebrew/bin/iina --help` and `codesign --verify --deep --strict
/Applications/IINA.app`. The independent `spctl --assess --type execute
--verbose=2 /Applications/IINA.app` returned **3**, `rejected`, with
`source=Notarized Developer ID`. This resolves download and installation, not the
VM's broader security-assessment discrepancy or GUI playback acceptance.
Local evidence: `iina-github-*.log` and `iina-github-results.json` under
`.tmp/macos-acceptance/evidence/`.

Google's `googlefonts/LatoGFVersion` repository at commit
`080cb69711ca050d91e9c866e58df7a73095c69a` retains all 18 original TTFs under
`src/`. Downloads of every file matched the operator's existing Lato2OFL files
byte for byte, without modifying that installation. The main `google/fonts`
catalog also supplies 18 version-2.015 fonts, but renames Hairline to Thin, Thin
to ExtraLight and Heavy to ExtraBold. A sampled comparison found identical
Regular glyph and metric tables, but different Heavy/ExtraBold tables.
The original `src/` files preserve compatibility; the catalog is not a
byte-identical replacement. Lato's cask remains unchanged and its vendor archive
still timed out. Evidence is under `.tmp/download-alternatives/`.

The Zed association smoke check passed for its declared `json`, `yaml`, `toml`
and `sh` extensions. `/bin/bash .tmp/mise-implementation/verify-entrypoint.sh`
exited **0**, including all four integration tests in **151.285 seconds**,
parsers, static checks, shell smoke, secret scanning and diff checks. The log is
`repository-verify-iina-github.log`. The VM was stopped after testing.

Sources:

- https://github.com/iina/iina/releases/tag/v1.5.0
- https://formulae.brew.sh/api/cask/iina.json
- https://mise.jdx.dev/url-replacements.html
- https://github.com/googlefonts/LatoGFVersion/tree/080cb69711ca050d91e9c866e58df7a73095c69a/src
- https://github.com/google/fonts/tree/main/ofl/lato

## Ghostty download recovery

On 2026-10-10, Ghostty's official 1.3.1 DMG became reachable again. Further cache
inspection found the original DMG in Nix's **binary cache**, in addition to the
repackaged `ghostty-bin` application. Its flat fixed-output path is derived from
the DMG checksum and filename, so recovery needs neither Nix installation nor
Hydra/GitHub release queries. The recovered DMG matched the official download
byte for byte, SHA-256
`18cff2b0a6cee90eead9c7d3064e808a252a40baf214aa752c1ecb793b8f5f69`.

`conf.d/ghostty/package.py` now attempts native cask apply/upgrade first. After
an official DMG download failure, it verifies current cask metadata, retrieves
that checksum's Nix source archive, accepts only a single regular-file NAR,
checks both cache hashes and the original cask SHA-256, and verifies the bundled
app's signature against Ghostty's identifier and Developer ID team `24VZTF6M5V`.
It then fills mise's URL-keyed download cache and retries the same native command.
The cask keeps version selection, installation receipts, app replacement,
completions/manpages and self-update handling. A missing mirror, altered archive,
changed cask metadata, or failed signature remains an error. An existing damaged
download is preserved for inspection instead of being silently replaced.

The package prerequisite hook invokes this adapter for the default, unconditional
macOS `latest` declaration. Maintenance passes `upgrade`, so native eligibility
checks still preserve current or running self-updating apps. Explicit pins,
conditional overrides, unsupported platforms and an undeclared Ghostty are left
to native mise. Direct native package commands bypass the prerequisite hook.
The adapter's native download budget defaults to two minutes unless supplied by
`MISE_HTTP_DOWNLOAD_TIMEOUT`. Cache layout compatibility was tested with
mise 2026.10.7; it does not broaden the cask release-age guarantees documented above.

The disposable `dotfiles-associations-023be87` VM ran the real bootstrap hook
with isolated configurations, caches, state, app directories and test prefixes:

| Scenario or command | Observed result |
| --- | --- |
| `mise bootstrap --yes`, official host allowed and Nix blocked | Installed 1.3.1 from the official DMG; no recovery |
| `mise bootstrap --yes`, official host blocked and Nix allowed | Recovered the byte-identical DMG, verified its signature and installed through the native cask |
| Repeat bootstrap and `python3 conf.d/setup/packages.py upgrade` | Exit 0; no recovery, app inode and executable timestamp unchanged |
| Both download hosts blocked | Exit 1; no app or completed archive installed |
| Corrupt pre-existing native download cache | Exit 1; corrupt file preserved, no fallback or app installation |
| Ghostty removed from the isolated declaration | No Ghostty installation or artifact download |
| Ghostty `+version` and `codesign --verify --deep --strict -R` with its identifier and team | Passed |

The active VM also installed Ghostty under `/Applications` through recovery.
Its first configuration smoke check found that this test copy had not deployed
the Ghostty dotfiles. Native deployment of just its three declared targets
followed by `mise -C ~ run --timeout 2m setup:ghostty` passed. Ghostty `+version`,
signature verification and a repeat IINA package apply passed as well.
An independent `spctl --assess --type execute --verbose=2` of the recovered app
returned **3**, `rejected`, `source=Notarized Developer ID`, matching the VM's
previous security-assessment discrepancy. This proves download, installation,
CLI and configuration validation, not GUI/Gatekeeper acceptance. No trust policy
was changed for these tests. The later
[Gatekeeper recheck](#gatekeeper-resolution-and-vm-limits) completed GUI and
security acceptance for Ghostty 1.3.1.

Local evidence under `.tmp/macos-acceptance/evidence/` includes
`ghostty-nix-results.json`, `ghostty-official-bootstrap.log`,
`ghostty-nix-bootstrap.log`, `ghostty-nix-apply-fixed.log`,
`ghostty-both-unavailable.log`, `ghostty-corrupt-official-cache.log`,
`ghostty-active-smoke-deployed.log`, `ghostty-installed-gatekeeper.log` and
`ghostty-signature-probe.log`.
These ignored artifacts are local evidence, not public setup inputs.

Repository verification completed on 2026-10-11 through `/bin/bash
.tmp/mise-implementation/verify-entrypoint.sh` (the isolated `mise run verify`
entrypoint), exit **0**. All five tests passed in **152.469 seconds**: the four
existing integration boundaries and the new DMG recovery check, including xz
and zstd archives. Compilation/parsing, static checks, shell smoke, secret
scanning and diff checks passed. See `repository-verify-ghostty-nix.log`.
The owned acceptance fixtures were removed and the VM was stopped; proof remains
in the host evidence directory.

Sources:

- https://nix.dev/manual/nix/2.35/protocols/store-path.html
- https://cache.nixos.org/lxpkzzmjcpscgwp2gb0bxgx43mn6i1xz.narinfo
- https://formulae.brew.sh/api/cask/ghostty.json
- https://github.com/jdx/mise/blob/v2026.10.7/src/system/packages/brew/cask/fetch.rs

## Gatekeeper resolution and VM limits

On 2026-10-11, the existing `dotfiles-associations-023be87` test copy still
allowed only App Store applications. Read-only inspection of
`/var/db/SystemPolicyConfiguration/SystemPolicy` showed `disabled=1` for the
Developer ID and Notarized Developer ID allow rules. After the authorized change
to "App Store & Known Developers" and completion of its authentication dialog,
those rules changed to `disabled=0`. Gatekeeper and SIP stayed enabled; no MDM or
DEP enrollment was present. No rule database was modified directly.

The same Ghostty 1.3.1 app and NordVPN 10.12.0 package then passed assessment.
Here, `source=Notarized Developer ID` identified the matching rule; it did not
override the accompanying `rejected` verdict. A disabled matching rule explains
that combination in Apple's policy-engine source:
https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_codesigning/lib/policyengine.cpp

The native installation command in that copy exited **0**:

```sh
PATH=/Users/admin/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  MISE_HTTP_TIMEOUT=60 MISE_HTTP_DOWNLOAD_TIMEOUT=2m \
  /Users/admin/.local/bin/mise -C /Users/admin \
  bootstrap packages install brew-cask:nordvpn --yes
```

The vendor postinstall logged `App passed notarization check`. Ghostty rendered
a terminal and ran `uname -m`, returning `arm64`. NordVPN reached its welcome
screen after declining optional telemetry. No account login or VPN tunnel was
tested.

An independent clone, `dotfiles-gatekeeper-fresh-20261011`, started from the
cached vanilla image recorded above, with neither app installed. Its effective
Gatekeeper rules were enabled and verified before downloading official artifacts
with Safari. The download files retained Safari quarantine and matched these
SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| Ghostty 1.3.1 DMG | `18cff2b0a6cee90eead9c7d3064e808a252a40baf214aa752c1ecb793b8f5f69` |
| NordVPN 10.12.0 PKG | `513c0603d3b5b36c2145853949548b3ed42a4830e4bcc73fd54d549124c1dd07` |

Ghostty was copied using Finder and opened through the normal first-launch
confirmation. macOS reported that its malware check found nothing; the terminal
ran `uname -m` successfully. NordVPN's package installed through the GUI, passed
its vendor postinstall checks and opened its welcome screen. A canceled Safari
download could not resume; downloading again from the same official URL worked.
Both installed apps and the package passed `spctl --assess` afterward, and both
apps passed strict code-signature verification. Gatekeeper and SIP remained on.
This follows Apple's quarantined-download and GUI workflow. Networking stayed
enabled, so it does not establish offline first launch:
https://developer.apple.com/forums/thread/130560

Final guest commands all exited **0**:

```sh
spctl --status
csrutil status
spctl --assess --type install --verbose=4 /Users/admin/Downloads/NordVPN.pkg
spctl --assess --type exec --verbose=4 /Applications/NordVPN.app
spctl --assess --type exec --verbose=4 /Applications/Ghostty.app
codesign --verify --deep --strict --verbose=2 /Applications/NordVPN.app
codesign --verify --deep --strict --verbose=2 /Applications/Ghostty.app
pkgutil --pkg-info com.nordvpn.macos
```

Both distribution containers passed `xcrun stapler validate` in the existing
test copy. `codesign --verify --deep --strict` and the notarization requirement
passed on the apps. `syspolicy_check distribution` on the inner apps reported
`Notary Ticket Missing` (exit 70); this did not prevent the tested container
installation and GUI launch. Apple's guidance distinguishes this warning from
a fatal failure: https://developer.apple.com/forums/thread/706442

The VM is useful for software acceptance, with these boundaries:

- The Cirrus image disables Gatekeeper and preconfigures login, SSH and sudo.
  It is not an untouched Setup Assistant installation. Its build recipe confirms
  this: https://github.com/cirruslabs/macos-image-templates/blob/main/templates/vanilla-golden-gate.pkr.hcl
- Tart 2.40.1 ran macOS 27.0 build 26A428 on arm64. The fresh clone had four CPUs,
  8 GiB RAM and a 50 GB virtual disk. Allocate more storage for the full setup;
  the earlier full-install VM required expansion to 160 GB.
- The macOS guest cannot provide nested virtualization for OrbStack/Docker.
  Tart documents nested virtualization only for supported Linux guests:
  https://tart.run/faq/#nested-virtualization-support
- Apple excludes Apple Media Services, including apps, from macOS VMs. App Store
  and `mas` acceptance therefore remains a physical-Mac check. Apple Account and
  most iCloud services can work on eligible macOS 15+ host/guest combinations;
  no Apple login was attempted: https://support.apple.com/en-gb/120468
- Metal was available as `Apple Paravirtual device`, and creating a command
  queue succeeded. Ghostty's rendered terminal confirms usable graphics for
  this test; the VM is not universally missing GPU support.
- Audio, USB accessories and clipboard sharing were disabled by the test run's
  flags. Physical audio routing, cameras, docks and driver operation remain
  untested. These flags are fixture choices, not universal macOS VM limits.
- The guest used NAT. Both official downloads succeeded during this recheck;
  that does not establish VPN tunnel behavior or explain earlier regional
  download failures.

Local ignored evidence under `.tmp/macos-acceptance/evidence/` includes
`gatekeeper-recheck-20261011.log`, `gatekeeper-effective-rules-20261011.log`,
`gatekeeper-after-auth-20261011.log`,
`nordvpn-native-retry-20261011.log`, `nordvpn-installed-20261011.log`,
`nordvpn-apple-checks-20261011.log`, `vm-app-runtime-20261011.log`,
`fresh-baseline-20261011.log`, `fresh-rules-after-20261011.log`,
`fresh-vm-limits-20261011.log`, `fresh-ghostty-download-20261011.log`,
`fresh-ghostty-launch-20261011.log`, `fresh-nordvpn-download-20261011.log` and
`fresh-app-acceptance-20261011.log`.
The Metal probe's output incorrectly labels command-queue creation as library
creation; only the command queue was exercised.
Both VMs used for this recheck were shut down after collecting evidence.

`/bin/bash .tmp/mise-implementation/verify-entrypoint.sh` ran the isolated
`mise run verify` and exited **0**. All five tests passed in **146.443 seconds**;
compilation/parsing, static checks, shell smoke, secret scanning and diff checks
passed. See `repository-verify-gatekeeper-20261011.log`. The coverage ledger
retained seven columns in all 191 data rows, and the new local documentation
link resolves to the acceptance section. No installer code changed in this pass.

## Outstanding acceptance

The fresh-Mac exercise in [POST_INSTALL.md](../POST_INSTALL.md) is in progress.
The following acceptance is still outstanding:

- Lato installation; IINA's security assessment and GUI acceptance; NordVPN's
  authenticated tunnel; optional packages, App Store installation, full package
  updates and driver operation.
- Complete native package status with the custom-tap evaluator.
- An untouched Setup Assistant/security flow, FileVault and immediate screen lock,
  the eight Mail/Safari defaults reported unset from Terminal, and actual launchd
  GUI behavior after required privacy approvals.
- Real capture/restore/reopen for all six apps, hardware routing and sessions,
  helper-process consistency, and recovery of real settings on another machine.
- Cask self-update and macOS privacy behavior after an actual app replacement.
- Real package exchange between two physical machines. Two-client isolated
  integration tests pass; macOS used manual sync and a local origin. The Ubuntu
  service acceptance below covers automatic setup application with a local origin.
- Hosted CI execution, Arch setup, or a non-arm64 full installation.

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
## Native capability audit

Reviewed upstream `jdx/mise` at `19e8c8f` and executed the contracts with mise
2026.10.7 on 2026-10-11. This audit follows the request to remove duplicate setup
logic and bring Ubuntu installation into scope.

| Responsibility | Native owner and remaining boundary |
| --- | --- |
| Install mise | `mise.run` selects the latest stable platform build and checks SHA-256. The wrapper only preserves foreign destinations, stages installation and keeps the previous executable. No mise release or checksum is pinned in this repository. |
| Version compatibility | Native `min_version` rejects unsupported mise versions. Duplicate Python version checks were removed. The initial mise binary is exempt from the tool cooldown so it can provide current bootstrap features. |
| Package installation | Native `[tools]`, `apt:`, `brew:` and `brew-cask:` declarations. Recipes use `/opt/homebrew` on macOS and `/home/linuxbrew/.linuxbrew` for CocoaPods and MozJPEG on Linux because the bottles expect those paths; no `brew` process runs. |
| Resource verification | One native `bootstrap status --missing --json` checks the declared resources, including tools and systemd units. Skipped required packages and native warnings still fail acceptance. |
| Files and permissions | Native dotfiles now own OrbStack's Docker plugin links; `bootstrap.directories` owns SSH directory permissions. The file guard still protects foreign links, redirected parents and edits to copied/template files: native apply can replace those without `--force`. |
| Agent and credential link chains | The small final adapter remains. A real isolated `dot apply` with `.agents/AGENTS.md` and `.codex/AGENTS.md` declared together fails before creating either: the second source does not exist yet. Native links also do not create the intentionally dangling VoiceInk auth link before login. |
| App-written shared keys | Native `merge` owns deployment. It has no command to capture just the owned keys back into a shared source; `edits.py` preserves that two-way contract and refuses concurrent changes. Native `dot add --changed` handles copied files, not merge entries. |
| macOS preference snapshots | Native history owns encryption and transfer. `macos.defaults` writes declared values but cannot export a running app's changed settings, represent binary plist data, or defer restoration until writers close. `preferences.py` owns only the allowlisted export/import and pending-restore decisions. It is not an encryption implementation. |
| Shared setup exchange | Native `dot save`, `sync`, `pull` and `recover` own history and Git conflicts. A pull does not install tools/services or render templates, so the serialized task still runs bootstrap after changed declarations and keeps failed setup pending. Native reload hooks explicitly exclude machine setup as their purpose. |
| Scheduling | Native LaunchAgent and systemd timer definitions are visible TOML files under `conf.d/history`. Only the local selected definition is activated. Both modes leave native history network exchange manual; the watcher saves locally. |
| Maintenance | Native mise upgrades tools/packages. The remaining task also updates Fisher, Neovim, GitHub extensions, skills and TPack, with success-only daily/weekly stamps. Mise's artifact cache does not provide this elapsed-time maintenance policy. |

Sources:

- https://mise.jdx.dev/installing-mise.html
- https://mise.jdx.dev/dotfiles/managed.html#conflicts
- https://mise.jdx.dev/dotfiles/edits.html#merge
- https://mise.jdx.dev/dotfiles/history.html#reload-an-application-after-restoring-files
- https://mise.jdx.dev/dotfiles/sync.html#sync-immediately
- https://mise.jdx.dev/dotfiles/encryption.html
- https://mise.jdx.dev/bootstrap/macos-defaults.html
- https://mise.jdx.dev/bootstrap/packages/brew.html
- https://mise.jdx.dev/bootstrap/packages/apt.html
- https://mise.jdx.dev/bootstrap/systemd.html


## Ubuntu and latest-installer acceptance

Executed on 2026-10-11 with disposable Ubuntu 26.04 arm64 and Ubuntu 24.04
x86_64 environments. The arm64 machine had a real systemd user manager; the
x86_64 Docker container tested installation/enrollment, not service operation.
All private keys and Git origins used for this exercise were synthetic/local.
GitHub's anonymous API quota was exhausted, so download verification used an
existing authenticated token passed only through stdin into process environment.
The test harness did not write the token to a file or to the public payload.

| Command or scenario | Result |
| --- | --- |
| `bash bootstrap/install-mise.sh` with a scratch destination on macOS arm64 | Selected latest stable 2026.10.7, verified upstream SHA-256 and preserved the older binary. An unchanged repeat preserved the executable timestamp. |
| Same installer with a deliberately corrupt release archive | Exit 1, checksum mismatch; the existing executable remained byte-identical and no pending replacement remained. |
| `./install.sh --seed-only --recipient` with a synthetic public recipient on Ubuntu 24.04 x86_64 | Exit 0; installed the official Linux x64 mise and Python, derived the machine ID and loaded Linux/common manifests only. |
| Ubuntu 24.04 `apt-cache show` for every declared system package | All 46 package names available. This is availability evidence, not a full x86_64 installation. |
| `./install.sh` on Ubuntu 26.04 arm64 | Exit 0 after the fixes below; all 46 system packages and 68 mise tools installed, configuration deployed, Fish selected as login shell, and the native history watcher running. No Homebrew executable or prefix. |
| `mise bootstrap status --missing --json` after application | Exit 0, including packages, tools, dotfiles, shell activation and services. |
| `mise exec -- bash -x ~/.config/mise/conf.d/nvim/setup.sh` after moving aside both Neovim data and state | Exit 0; fresh plugin restoration, native builds, language servers and parsers. |
| Native systemd timer/service running `mise -C ~ run sync --automatic` | Successful local history exchange and setup application, `ExecMainStatus=0`. |
| Add a new `pipx:yamllint` declaration and a content-managed file, then start the generated sync service | Installed yamllint 1.38.0 and wrote the declared file; native resource status passed. This exercised automatic application of software changes with a local private origin. |
| Change local mode to manual, then `mise -C ~ run config apply` | Exit 0; native apply removed both the sync service and timer, retained the history watcher, and `mise run sync --automatic` reported disabled. |
| `mise run verify` through the isolated macOS entrypoint | Exit 0; five tests in 159.845 seconds, Swift/type/syntax/schema/workflow checks, shell smoke, secret and diff checks passed. |
| `mise run verify` in the Ubuntu VM with an isolated verification configuration | Exit 0; five tests in 11.116 seconds and every applicable parser/static/smoke check passed. Swift framework checks run only on macOS. |

Real installation found two portability defects: the shared Curl configuration's
`remove-on-error` conflicted with Rustup's resumed downloads, and the default
binary sources for procs, resvg and tlrc lacked Linux arm64 builds. Removing that
Curl option preserved resume behavior; native `cargo:` declarations now install
those three tools. TLRC now chooses its platform's default cache directory.

The first Neovim setup returned a failure without a useful error. A traced rerun,
an isolated native-library build, and a fresh data/state run succeeded; no cause
was established and no speculative Neovim patch was added. Subsequent complete
bootstrap and automatic service runs passed. An early scheduler probe ran outside
the setup lock and correctly refused an in-progress native history operation;
the serialized production path and later service runs passed.

CI now declares both macOS and Ubuntu jobs. Hosted execution, Arch packages,
a full x86_64 setup, real credentials and cross-machine network/hardware acceptance
remain outside this evidence. The remaining macOS GUI and app acceptance gaps
are listed under [Outstanding acceptance](#outstanding-acceptance).
No bootstrap, package installation, preference import or service registration
was executed on the operator's Mac.

Local ignored evidence is in `.tmp/native-ubuntu/evidence/`: installer and
checksum logs, `ubuntu-amd64-enroll.log`, `ubuntu-24-package-availability.log`,
`ubuntu-bootstrap-retry.log`, `ubuntu-nvim-fresh.log`, `ubuntu-scheduler-journal.log`,
`ubuntu-scheduler-application.log`, `ubuntu-scheduler-disable.log`, native status
JSON, `repository-verify-final.log` and `repository-verify-linux.log`.
The owned Ubuntu VM and containers were removed, and OrbStack was returned to
its initial stopped state. The ignored logs remain available locally.

## AutoFirma cask release discovery

Verified on 2026-10-11. AutoFirma no longer has a pinned version, archive URL,
checksum or package filename. Its setup task reads all four from
https://formulae.brew.sh/api/cask/autofirma.json. The macOS `update` task checks
this release daily and prepares a newer installer, leaving maintenance pending
until the user completes it. Native mise still rejects this cask's
`installer manual:` artifact, so the small vendor-installer adapter remains.

The current cask returned 1.9.2. A real download into isolated state passed the
cask SHA-256 and `pkgutil --check-signature`, including Apple's notarization
assessment. The ZIP spells its package `Autofirma`, while the cask spells it
`AutoFirma`; the adapter now accepts one case-insensitive filename match.
No installer was launched on the operator's Mac.

Commands and evidence:

- `python3 .tmp/cli-portability/check-autofirma.py`: exit 0. An installed
  current version avoided another archive download; changing the fixture cask
  version and package filename prepared the new release; a checksum mismatch
  wrote no package and did not reach signature verification.
- `python3 .tmp/cli-portability/check-autofirma.py --live`: exit 0; actual
  cask discovery, download, checksum and Apple package signature passed. The
  harness expects the production task's pending-installation error.
- `bash .tmp/mise-implementation/verify-entrypoint.sh`: exit 0; runs
  `mise run verify` with isolated mise directories. Five integration tests
  passed in 152.977 seconds, plus compilation, syntax, schema, shell smoke,
  secret and diff checks.

The local ignored scripts and logs are under `.tmp/cli-portability/`.
The previously completed 1.9.2 VM installation remains the GUI evidence;
this check did not claim a new GUI installation or a real future release.

## CLI platform coverage

Reviewed all 45 macOS entries and nine shared tools in `conf.d/cli` on
2026-10-11. The shared tools already load on Linux. Of the 45 macOS entries,
42 have Linux declarations; CocoaPods and MozJPEG were the two missing entries.
The other three require macOS. The complete mapping is:

| Linux owner | Tools from the macOS manifest |
| --- | --- |
| `apt:`, same name | coreutils, moreutils, findutils, grep, zstd, less, figlet, rename, fswatch, watchman, rsync, gnupg, aria2, ffmpeg, pngquant |
| `apt:`, distro name | gnu-sed → sed; gnu-tar → tar; pkgconf → pkg-config; watch → procps; ykman → yubikey-manager; exiftool → libimage-exiftool-perl; p7zip → 7zip |
| mise `[tools]`, same name | jq, cmake, eza, hyperfine, fd, ast-grep, fzf, zoxide, dust, duf, worktrunk, actionlint, shellcheck, gitleaks |
| `cargo:` | procs, lolcrab, resvg |
| `aqua:bensadeh/tailspin` | tailspin |
| Native `brew:` | cocoapods, mozjpeg |
| macOS only | remindctl (Apple Reminders), mas (Mac App Store), mole (macOS maintenance) |

The formula APIs confirm arm64 and x86_64 Linux bottles for both additions:
https://formulae.brew.sh/api/formula/cocoapods.json and
https://formulae.brew.sh/api/formula/mozjpeg.json. The macOS exclusions are
documented at https://github.com/openclaw/remindctl,
https://formulae.brew.sh/formula/mas and https://formulae.brew.sh/formula/mole.

Native mise installs the bottles into `/home/linuxbrew/.linuxbrew`, without a
Homebrew executable. MozJPEG's keg-only `bin` directory is on the Linux PATH;
the redundant `apt:libjpeg-turbo-progs` declaration is removed. The first real
install exposed a Ruby runtime failure on both architectures: `libcrypt.so.2`
was missing. The Linux manifest now explicitly declares `libxcrypt` and `libffi`,
the libraries listed in Ruby's `uses_from_macos` metadata at
https://formulae.brew.sh/api/formula/ruby.json. Ruby's FFI, OpenSSL and YAML
loading passed after that correction.

Fresh Ubuntu 26.04 arm64 and Ubuntu 24.04 x86_64 containers installed CocoaPods
1.17.0 and MozJPEG 4.1.5 through `mise bootstrap packages apply --manager brew
--yes`. `pod --version` and `pod ipc spec /fixture/Fixture.podspec` passed.
`cjpeg`, `jpegtran` and `djpeg` encoded, optimized and decoded a small image.
A repeated apply reported all four declared recipes already installed;
`mise bootstrap packages status --json` reported each as `installed`.
Neither container had a `brew` executable. CocoaPods verification covers its
CLI and podspec metadata; Xcode builds still require macOS.

The fresh-install harness initially used an unsupported `--manager` flag for
`packages status`. Removing that flag and rerunning the functional/status checks
passed on both architectures. This was a harness error after successful package
and runtime checks, not an installation failure.

Ignored evidence in `.tmp/cli-portability/` includes `cli-audit.tsv`, the initial
`linux-*.log` failures, `linux-*-retry.log`, `linux-*-fresh.log`, and the final
`linux-*-final.log` functional and native-status results. These checks exercised
the new packages; the earlier Ubuntu acceptance section retains the evidence
for the unchanged CLI packages, full bootstrap and services.

`bash .tmp/mise-implementation/verify-entrypoint.sh` ran `mise run verify`
against the final implementation and exited 0: five tests in 154.592 seconds,
plus compilation, syntax, schema, shell smoke, secret and diff checks. The two
owned test containers were removed and OrbStack returned to its initial stopped
state. No Linux packages or bootstrap state were applied to the operator's Mac.
