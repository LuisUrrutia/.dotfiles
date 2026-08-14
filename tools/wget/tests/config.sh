#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
WGET_CONFIG="$DOTFILES_ROOT/tools/wget/config/.wgetrc"

if ! command -v wget >/dev/null 2>&1; then
  printf 'wget is required to validate its global config\n' >&2
  exit 1
fi

config=$(<"$WGET_CONFIG")

if [[ "$config" != *'robots = off'* ]]; then
  printf 'Wget must ignore robots.txt for explicit user downloads\n' >&2
  exit 1
fi

if [[ "$config" != *'user_agent = Mozilla/5.0'* ]]; then
  printf 'Wget must retain the browser user agent\n' >&2
  exit 1
fi

while IFS= read -r line; do
  case "$line" in
  timestamping* | continue* | trust_server_names* | content_disposition* | adjust_extension*)
    printf 'Stateful Wget default is not allowed: %s\n' "$line" >&2
    exit 1
    ;;
  esac
done <"$WGET_CONFIG"

output=$(wget \
  --config="$WGET_CONFIG" \
  --output-document=/dev/null \
  --timeout=1 \
  --tries=1 \
  http://127.0.0.1:9/ 2>&1 || true)

if [[ "$output" == *'timestamping does nothing'* ]]; then
  printf 'Wget still applies timestamping globally\n' >&2
  exit 1
fi
