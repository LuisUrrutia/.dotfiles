#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  cat <<'EOF'
Usage: ./install.sh [--dry-run | --mise-only] [enrollment options]

Fresh macOS arm64 setup. Checks Full Disk Access, Command Line Tools and sudo,
installs the official mise binary, then enrolls this machine.

Enrollment options: --machine ID --apps app,app --sync manual|automatic
                    --origin SSH_URL --recipient PUBLIC_KEY --adopt SSH_URL
                    --seed-only
Rerunning preserves the active setup and existing local choices.
Use mise run enroll -- --help for all enrollment options.
EOF
  exit 0
fi
if [[ "${1:-}" == --dry-run ]]; then
  echo 'Plan: check macOS arm64 and non-root user; Full Disk Access; CLT; sudo.'
  echo 'Then install official mise 2026.10.7, enroll missing active sources, validate and bootstrap.'
  echo 'No files, packages, preferences, services or credentials were changed.'
  exit 0
fi
if [[ "$(id -u)" == 0 ]]; then
  echo 'Run setup as the user who will own the configuration, without sudo.' >&2
  exit 1
fi
source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "${1:-}" == --mise-only ]]; then
  exec /bin/bash "$source_root/bootstrap/install-mise.sh"
fi
if [[ "$(uname -s)/$(uname -m)" != Darwin/arm64 ]]; then
  echo 'Full setup currently requires macOS arm64. The portable modules are prepared for future Linux support.' >&2
  exit 1
fi
if ! /bin/ls "$HOME/Library/Safari" >/dev/null 2>&1; then
  echo 'Grant this terminal Full Disk Access, restart it, then rerun setup.' >&2
  exit 1
fi
if ! /usr/bin/xcrun --find clang >/dev/null 2>&1; then
  if [[ -t 0 ]]; then
    /usr/bin/xcode-select --install || true
  fi
  echo 'Finish installing Xcode Command Line Tools, then rerun setup.' >&2
  exit 1
fi
if [[ -t 0 ]]; then
  /usr/bin/sudo -v
else
  /usr/bin/sudo -n -v
fi
if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
  echo 'This is a fresh-install setup. Use it after reinstalling macOS; it does not convert a Homebrew installation.' >&2
  exit 1
fi
if [[ ! -f "$source_root/bootstrap/enroll.py" ]]; then
  destination="$HOME/.dotfiles"
  [[ ! -e "$destination" ]] || { echo "Refusing existing checkout: $destination" >&2; exit 1; }
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' \
    /usr/bin/git clone git@github.com:LuisUrrutia/.dotfiles.git "$destination"
  exec /bin/bash "$destination/install.sh" "$@"
fi
/bin/bash "$source_root/bootstrap/install-mise.sh"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
exec "$HOME/.local/bin/mise" exec python@3 -- python3 "$source_root/bootstrap/enroll.py" "$@"
