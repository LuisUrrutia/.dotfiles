#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT_DIR/tools/bin/config/.local/bin/gha-pins"
TMP_DIR="$(mktemp -d)"
FAKE_BIN="$TMP_DIR/bin"

CHECKOUT_SHA="1111111111111111111111111111111111111111"
CHECKOUT_V6_SHA="3333333333333333333333333333333333333333"
SETUP_NODE_TAG_OBJECT="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
SETUP_NODE_SHA="2222222222222222222222222222222222222222"
CODEQL_SHA="4444444444444444444444444444444444444444"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

write_fake_gh() {
  mkdir -p "$FAKE_BIN"

  cat >"$FAKE_BIN/gh" <<FAKE_GH
#!/usr/bin/env bash
set -euo pipefail

[[ "\${1:-}" == "api" ]] || exit 2
path="\${2:-}"

case "\$path" in
  repos/actions/checkout/releases/latest)
    printf 'v7.0.0\n'
    ;;
  repos/actions/checkout/git/ref/tags/v7.0.0)
    printf '%s commit\n' "$CHECKOUT_SHA"
    ;;
  repos/actions/checkout/git/ref/tags/v6.0.0)
    printf '%s commit\n' "$CHECKOUT_V6_SHA"
    ;;
  repos/actions/setup-node/releases/latest)
    printf 'v5.1.0\n'
    ;;
  repos/actions/setup-node/git/ref/tags/v5.1.0)
    printf '%s tag\n' "$SETUP_NODE_TAG_OBJECT"
    ;;
  repos/actions/setup-node/git/tags/$SETUP_NODE_TAG_OBJECT)
    printf '%s\n' "$SETUP_NODE_SHA"
    ;;
  repos/github/codeql-action/releases/latest)
    printf 'v3.30.3\n'
    ;;
  repos/github/codeql-action/git/ref/tags/v3.30.3)
    printf '%s commit\n' "$CODEQL_SHA"
    ;;
  repos/octo/norelease/releases/latest)
    exit 1
    ;;
  *)
    printf 'unexpected gh api path: %s\n' "\$path" >&2
    exit 2
    ;;
esac
FAKE_GH
  chmod +x "$FAKE_BIN/gh"
}

write_fake_gh
export PATH="$FAKE_BIN:/usr/bin:/bin"

test_audit_passes_pinned_workflows() {
  local dir="$TMP_DIR/audit-pass"
  local output=""

  mkdir -p "$dir"
  cat >"$dir/ci.yml" <<EOF
jobs:
  build:
    steps:
      - uses: actions/checkout@$CHECKOUT_SHA # v7.0.0
      - uses: "actions/setup-node@$SETUP_NODE_SHA" # v5.1.0
      - uses: ./local/action
      - uses: docker://alpine:3.20
EOF

  output="$("$SCRIPT" audit "$dir")"
  [[ "$output" == *"all remote actions are SHA-pinned"* ]]
}

test_audit_rejects_unpinned_refs() {
  local dir="$TMP_DIR/audit-fail"
  local error_file="$TMP_DIR/audit-fail.err"

  mkdir -p "$dir"
  cat >"$dir/ci.yml" <<EOF
jobs:
  build:
    steps:
      - uses: actions/checkout
      - uses: actions/setup-node@v5
      - uses: github/codeql-action/init@$CODEQL_SHA
EOF

  if "$SCRIPT" audit "$dir" >/dev/null 2>"$error_file"; then
    printf 'expected audit to fail\n' >&2
    return 1
  fi

  grep -q 'action is not pinned: actions/checkout' "$error_file"
  grep -q 'action ref is not a full SHA: actions/setup-node@v5' "$error_file"
  grep -q 'pinned action is missing a version comment: github/codeql-action/init' "$error_file"
}

test_audit_fails_on_missing_path() {
  if "$SCRIPT" audit "$TMP_DIR/does-not-exist" >/dev/null 2>&1; then
    printf 'expected missing path to fail\n' >&2
    return 1
  fi
}

test_latest_resolves_release_and_annotated_tags() {
  local output=""

  output="$("$SCRIPT" latest actions/checkout)"
  [[ "$output" == "uses: actions/checkout@$CHECKOUT_SHA # v7.0.0" ]]

  output="$("$SCRIPT" latest actions/checkout v6.0.0)"
  [[ "$output" == "uses: actions/checkout@$CHECKOUT_V6_SHA # v6.0.0" ]]

  # Annotated tags must be peeled to the underlying commit.
  output="$("$SCRIPT" latest actions/setup-node)"
  [[ "$output" == "uses: actions/setup-node@$SETUP_NODE_SHA # v5.1.0" ]]
}

test_update_rewrites_stale_pins() {
  local dir="$TMP_DIR/update"
  local file="$dir/ci.yml"

  mkdir -p "$dir"
  cat >"$file" <<EOF
jobs:
  build:
    steps:
      - uses: actions/checkout@v6
      - uses: "actions/setup-node@old-sha"
      - uses: github/codeql-action/init@0000000000000000000000000000000000000000 # v3.0.0
      - uses: ./local/action
      - uses: docker://alpine:3.20
EOF

  "$SCRIPT" update "$file" >/dev/null

  diff "$file" - <<EOF
jobs:
  build:
    steps:
      - uses: actions/checkout@$CHECKOUT_SHA # v7.0.0
      - uses: "actions/setup-node@$SETUP_NODE_SHA" # v5.1.0
      - uses: github/codeql-action/init@$CODEQL_SHA # v3.30.3
      - uses: ./local/action
      - uses: docker://alpine:3.20
EOF

  "$SCRIPT" audit "$file" >/dev/null
}

test_update_is_idempotent() {
  local dir="$TMP_DIR/update-idempotent"
  local file="$dir/ci.yml"
  local output=""

  mkdir -p "$dir"
  cat >"$file" <<EOF
jobs:
  build:
    steps:
      - uses: actions/checkout@$CHECKOUT_SHA # v7.0.0
EOF
  cp "$file" "$file.orig"

  output="$("$SCRIPT" update "$file")"
  [[ "$output" == "gha-pins: all remote actions pinned to their latest release" ]]
  cmp -s "$file" "$file.orig"
}

test_update_skips_actions_without_releases() {
  local dir="$TMP_DIR/update-norelease"
  local file="$dir/ci.yml"
  local error_file="$TMP_DIR/update-norelease.err"

  mkdir -p "$dir"
  cat >"$file" <<EOF
jobs:
  build:
    steps:
      - uses: octo/norelease@v1
      - uses: actions/checkout@v6
EOF

  if "$SCRIPT" update "$file" >/dev/null 2>"$error_file"; then
    printf 'expected update to fail for release-less action\n' >&2
    return 1
  fi

  grep -q 'no release found for octo/norelease; skipping' "$error_file"
  grep -q "uses: octo/norelease@v1" "$file"
  grep -q "uses: actions/checkout@$CHECKOUT_SHA # v7.0.0" "$file"
}

tests=(
  test_audit_passes_pinned_workflows
  test_audit_rejects_unpinned_refs
  test_audit_fails_on_missing_path
  test_latest_resolves_release_and_annotated_tags
  test_update_rewrites_stale_pins
  test_update_is_idempotent
  test_update_skips_actions_without_releases
)

for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
