# Own Portable Global CLIs with mise

Status: accepted

The repository must bootstrap a freshly formatted Mac and later update the same
software from tracked declarations. A command managed by more than one package
manager creates path shadowing, ambiguous upgrades, and machine-to-machine
drift. Exact installed-version receipts are not useful for this personal
two-machine setup; the desired state is the current release within a declared
channel.

Homebrew owns macOS applications, system utilities, native dependencies, and
packages selected through optional Brewfile profiles. The global mise config
owns Core Install runtimes and portable ecosystem CLIs distributed through
npm, pipx, Aqua, GitHub releases, or another mise backend. Claude Code, Codex,
and TPack are portable global CLIs and therefore belong to mise; the Claude
desktop app and CodexBar remain Homebrew casks. Project dependencies remain
project-local.

Each persistent command has exactly one Package Owner. Versions use moving
channels such as `latest`, `lts`, or a major version instead of an installed
version lockfile. Software Maintenance upgrades each owner and prunes obsolete
mise versions, but does not reconcile all installed software, remove unrelated
manual installs, or synchronize the repository.

When ownership moves, bootstrap installs and verifies the replacement before
retiring only the known legacy package. This keeps a failed migration from
removing a working command while allowing clean clones and existing Macs to
converge on the same tracked ownership.
