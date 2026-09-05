#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script_path="${script_dir}/../config/.local/bin/macfuse-guard"
brew_fixture="${script_dir}/fixtures/brew-macfuse"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

run_guard() {
  local version="$1"
  local installed="$2"
  local pinned="$3"
  local log_file="$4"

  FAKE_MACFUSE_VERSION="${version}" \
    FAKE_MACFUSE_INSTALLED="${installed}" \
    FAKE_MACFUSE_PINNED="${pinned}" \
    FAKE_BREW_LOG="${log_file}" \
    BREW_BIN="${brew_fixture}" \
    "${script_path}" reconcile
}

blocked_log="${test_root}/blocked.log"
blocked_output="$(run_guard "5.3.3" true false "${blocked_log}")"
grep -Fxq "pin --cask macfuse" "${blocked_log}"
grep -Fq "Blocked macFUSE 5.3.3; cask is pinned" <<<"${blocked_output}"

allowed_log="${test_root}/allowed.log"
allowed_output="$(run_guard "5.3.4" true true "${allowed_log}")"
grep -Fxq "unpin --cask macfuse" "${allowed_log}"
grep -Fq "Allowed macFUSE 5.3.4; cask is unpinned" <<<"${allowed_output}"

unchanged_log="${test_root}/unchanged.log"
unchanged_output="$(run_guard "5.3.4" true false "${unchanged_log}")"
if grep -Eq '^(pin|unpin) ' "${unchanged_log}"; then
  echo "an allowed, unpinned cask should remain unchanged" >&2
  exit 1
fi
grep -Fq "Allowed macFUSE 5.3.4; cask is unpinned" <<<"${unchanged_output}"

missing_log="${test_root}/missing.log"
missing_output="$(run_guard "5.3.3" false false "${missing_log}")"
grep -Fq "macFUSE is not installed; nothing to guard" <<<"${missing_output}"
if grep -Eq '^(info|pin|unpin) ' "${missing_log}"; then
  echo "an absent cask should not be inspected or changed" >&2
  exit 1
fi

echo "macfuse-guard tests passed"
