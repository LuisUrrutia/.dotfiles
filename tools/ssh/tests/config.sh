#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG="$ROOT_DIR/tools/ssh/config/.ssh/config"

assert_config_line() {
  local rendered_config="$1"
  local expected_line="$2"
  local host="$3"

  if ! grep -Fqx "$expected_line" <<<"$rendered_config"; then
    printf 'SSH config test: %s is missing %q\n' "$host" "$expected_line" >&2
    return 1
  fi
}

render_config() {
  ssh -G -F "$CONFIG" "$1" 2>/dev/null
}

github_config="$(render_config git@github.com)"
gitlab_config="$(render_config git@gitlab.com)"
other_config="$(render_config example.com)"
one_password_agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

for host_config in "$github_config" "$gitlab_config"; do
  assert_config_line "$host_config" 'identityagent none' 'Git host'
  assert_config_line "$host_config" 'identitiesonly yes' 'Git host'
  assert_config_line "$host_config" 'identityfile ~/.ssh/id_ed25519' 'Git host'
done

assert_config_line "$other_config" "identityagent $one_password_agent" 'other host'
assert_config_line "$other_config" 'identitiesonly no' 'other host'

printf 'SSH config test: ok\n'
