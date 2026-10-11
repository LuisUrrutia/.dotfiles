#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  cat <<'EOF'
Usage: ./install.sh [--dry-run | --mise-only] [enrollment options]

Fresh macOS arm64 or Ubuntu (arm64/x86_64) setup. Checks platform prerequisites,
installs the latest stable official mise with SHA-256 verification, then enrolls
this machine. Managed tools keep their configured release cooldown.

Enrollment options: --machine ID --apps app,app --sync manual|automatic
                    --origin GIT_URL --recipient PUBLIC_KEY --adopt GIT_URL
                    --seed-only --recover
Rerunning preserves the active setup and existing local choices.
Use mise run enroll -- --help for all enrollment options.
EOF
  exit 0
fi
if [[ "${1:-}" == --dry-run ]]; then
  echo 'Plan: check non-root user and sudo; macOS: Full Disk Access and CLT; Ubuntu: curl, Git and CA certificates.'
  echo 'Then install the latest stable official mise with SHA-256 verification, enroll missing sources and bootstrap.'
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
case "$(uname -s)/$(uname -m)" in
Darwin/arm64)
  if ! /bin/ls "$HOME/Library/Safari" >/dev/null 2>&1; then
    echo 'Grant this terminal Full Disk Access, restart it, then rerun setup.' >&2
    exit 1
  fi
  if ! /usr/bin/xcrun --find clang >/dev/null 2>&1; then
    echo 'Run xcode-select --install, finish installing Command Line Tools, then rerun setup.' >&2
    exit 1
  fi
  if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
    echo 'This is a fresh-install setup. Use it after reinstalling macOS; it does not convert a Homebrew installation.' >&2
    exit 1
  fi
  ;;
Linux/aarch64 | Linux/x86_64)
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "$ID" != ubuntu ]]; then
    echo 'Full Linux setup currently supports Ubuntu. Other distributions need their own system packages.' >&2
    exit 1
  fi
  ;;
*)
  echo 'Full setup supports macOS arm64 and Ubuntu arm64/x86_64.' >&2
  exit 1
  ;;
esac
if ! sudo -n true; then
  echo 'Run sudo -v in your terminal, then rerun setup.' >&2
  exit 1
fi
if [[ "$(uname -s)" == Linux ]] && { ! command -v curl >/dev/null || ! command -v git >/dev/null || [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; }; then
  sudo -n apt-get update
  sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install --yes ca-certificates curl git
fi
if [[ ! -f "$source_root/bootstrap/enroll.py" ]]; then
  destination="$HOME/.dotfiles"
  [[ ! -e "$destination" ]] || {
    echo "Refusing existing checkout: $destination" >&2
    exit 1
  }
  GIT_TERMINAL_PROMPT=0 \
    /usr/bin/git clone https://github.com/LuisUrrutia/.dotfiles.git "$destination"
  exec /bin/bash "$destination/install.sh" "$@"
fi
/bin/bash "$source_root/bootstrap/install-mise.sh"
export PATH="$HOME/.local/bin:$PATH"
export MISE_MINIMUM_RELEASE_AGE="${MISE_MINIMUM_RELEASE_AGE:-3d}"
exec "$HOME/.local/bin/mise" exec python@3 -- python3 "$source_root/bootstrap/enroll.py" "$@"
