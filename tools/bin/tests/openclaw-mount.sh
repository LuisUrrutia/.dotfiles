#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script_path="${script_dir}/../config/.local/bin/openclaw-mount"
tailscale_fixture="${script_dir}/fixtures/tailscale"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

make_macfuse_plist() {
  local path="$1"
  local version="$2"

  /usr/bin/plutil -create xml1 "${path}"
  /usr/bin/plutil -insert CFBundleShortVersionString -string "${version}" "${path}"
}

run_mount() {
  local plist_path="$1"
  local mount_point="$2"
  local tailscale_state="${3:-Running}"

  FAKE_TAILSCALE_STATE="${tailscale_state}" \
  OPENCLAW_MACFUSE_INFO_PLIST="${plist_path}" \
    OPENCLAW_MOUNT_POINT="${mount_point}" \
    SSHFS_BIN="${test_root}/missing-sshfs" \
    TAILSCALE_BIN="${tailscale_fixture}" \
    "${script_path}" mount 2>&1
}

bad_plist="${test_root}/macfuse-5.3.3.plist"
good_plist="${test_root}/macfuse-5.3.2.plist"
mount_point="${test_root}/OpenClaw"
mkdir -p "${mount_point}"
make_macfuse_plist "${bad_plist}" "5.3.3"
make_macfuse_plist "${good_plist}" "5.3.2"

if bad_output="$(run_mount "${bad_plist}" "${mount_point}")"; then
  echo "expected macFUSE 5.3.3 to be rejected" >&2
  exit 1
fi
grep -Fq "macFUSE 5.3.3 breaks SSHFS" <<<"${bad_output}"

if good_output="$(run_mount "${good_plist}" "${mount_point}")"; then
  echo "expected the missing sshfs binary to stop the mount" >&2
  exit 1
fi
grep -Fq "sshfs is not installed or executable" <<<"${good_output}"

if disconnected_output="$(run_mount "${good_plist}" "${mount_point}" "Stopped")"; then
  echo "expected disconnected Tailscale to stop the mount" >&2
  exit 1
fi
grep -Fq "Tailscale is not connected (state: Stopped)" <<<"${disconnected_output}"

reconcile_output="$(
  FAKE_TAILSCALE_STATE="Stopped" \
    OPENCLAW_MOUNT_POINT="${mount_point}" \
    TAILSCALE_BIN="${tailscale_fixture}" \
    "${script_path}" reconcile
)"
grep -Fq "Tailscale is Stopped; volume remains unmounted" <<<"${reconcile_output}"

"${script_path}" --help | grep -Fq "Usage: openclaw-mount COMMAND"

echo "openclaw-mount tests passed"
