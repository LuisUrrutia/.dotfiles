# Mise compatibility evidence

Tested on 2026-10-10, macOS arm64, with the official **2026.10.3** binary.
This is the newest stable release older than the repository's three-day release
cooldown at selection time. The existing system mise was not upgraded.

Release: https://github.com/jdx/mise/releases/tag/v2026.10.3

The macOS arm64 tarball's SHA-256 matched the release asset digest:
`28ecc8640b0a28dab52817766f37fecfd898f1dff82e03f36fcb072e971f9246`.

## Observed contracts

An isolated experiment used two temporary homes, separate config/data/cache/state
directories, synthetic preferences and SSH encryption keys, and a local bare Git
origin. It ran the actual release binary and Git, without installing packages,
starting services, or changing the operator's configuration.

- Global `conf.d/<tool>/mise.toml` loads alongside `config.toml`.
- `miserc.toml` with `auto_env = true` selects `mise.macos.toml` and excludes
  `mise.linux.toml`. An optional environment in `miserc.local.toml` adds its module.
- Relative `symlink-each` sources resolve within their module. Targets contain
  application files, not mise manifests. Target directories remain directories.
- Tracking the active configuration directory includes module manifests and
  their source contents. Entry exclusions keep local enrollment files out.
- A separate encrypted tracked subtree saves an age ciphertext blob on its first
  checkpoint. Its synthetic plaintext does not occur in that Git blob.
- Adoption without a decryption key fails with `cannot unlock`. Supplying the
  matching synthetic identity allows adoption and restores the original bytes.
- Adoption preserves the second machine's `config.local.toml` and does not copy
  the first machine's `miserc.local.toml` optional selection.
- Native save/sync/pull transfers a changed source file to the second machine.
- Concurrent edits to the same lines leave the local file intact. **Sync returns
  zero with a warning in this case**; `dot pull --yes` fails, and status JSON
  exposes `history.sync.conflicts`. A successful sync alone is not an apply gate.
- `bootstrap plan --json` does not include all dotfile entries in this version.
  Use `dot status --json` for their resolved paths, modes, origins and state.
- `config get` reads one stored file, not the merged effective configuration.

Command: `python3 .tmp/mise-implementation/probe.py` — passed. The experiment and
its output are ignored local scratch, not the permanent verification suite.
Production integration checks must exercise the repository adapters separately.

## Limits of this evidence

Package recipes, installer packages, App Store authentication, Full Disk Access,
login-shell changes, launchd registration and real application restore have not
run on a disposable fresh Mac. Existing Homebrew receipts on the operator's Mac
cannot establish that native mise installation works. Those acceptance checks
remain open; no live setup has been performed.

Current documentation describes newer functionality than this baseline. Do not
rely on `dot save --re-encrypt`: it is absent from the tested release's help.

Self-updating casks avoid unnecessary replacement, but replacing a bundle can
still invalidate macOS privacy grants. This setup must not promise to automate
those grants or guarantee their preservation:
https://mise.jdx.dev/bootstrap/packages/brew-cask.html#macos-privacy-permissions

Native copies can overwrite edited targets, and symlinks can be repointed.
Repository application needs a preservation check before invoking native apply.
Native history owns Git exchange and conflict resolution; there is no reason to
implement another synchronization engine.

References:

- https://mise.jdx.dev/bootstrap/modules.html
- https://mise.jdx.dev/configuration/environments.html#platform-environments
- https://mise.jdx.dev/dotfiles/managed.html
- https://mise.jdx.dev/dotfiles/history.html
- https://mise.jdx.dev/dotfiles/encryption.html
- https://mise.jdx.dev/dotfiles/sync.html
