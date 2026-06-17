#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT_DIR/tools/bin/config/.local/bin/install-ssh-key-from-1password"
TMP_DIR="$(mktemp -d)"
PRIVATE_KEY_CONTENT="FAKE_OPENSSH_PRIVATE_KEY_BODY"
PUBLIC_KEY_CONTENT="ssh-ed25519 AAAAexample test@example.com"
HOME_DIR=""
FAKE_BIN=""
GIT_LOG=""

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

write_fake_op() {
  cat >"$FAKE_BIN/op" <<'FAKE_OP'
#!/usr/bin/env bash
set -euo pipefail

command="$1"
shift

case "$command" in
  read)
    out_file=""
    file_mode="0600"
    reference=""

    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --out-file)
          out_file="$2"
          shift 2
          ;;
        --file-mode)
          file_mode="$2"
          shift 2
          ;;
        --force | -f)
          shift
          ;;
        *)
          reference="$1"
          shift
          ;;
      esac
    done

    [[ -n "$out_file" ]] || exit 2

    case "$reference" in
      private-ref | op://Vault/GitHub/private\ key | op://Vault/GitHub/private\ key?ssh-format=openssh | op://Vault/Deploy/private\ key?ssh-format=openssh)
        printf '%s\n' "${PRIVATE_KEY_CONTENT:?}" >"$out_file"
        ;;
      public-ref | op://Vault/GitHub/public\ key)
        printf '%s\n' "${PUBLIC_KEY_CONTENT:?}" >"$out_file"
        ;;
      *)
        printf 'unexpected reference: %s\n' "$reference" >&2
        exit 2
        ;;
    esac

    chmod "$file_mode" "$out_file"
    ;;
  item)
    subcommand="$1"
    shift

    case "$subcommand" in
      list)
        printf '%s\n' '[{"id":"github-ssh","title":"GitHub SSH"},{"id":"deploy-ssh","title":"Deploy SSH"}]'
        ;;
      get)
        item_id="$1"

        case "$item_id" in
          github-ssh)
            printf '%s\n' '{"id":"github-ssh","title":"GitHub SSH","fields":[{"label":"private key","reference":"op://Vault/GitHub/private key"},{"label":"public key","reference":"op://Vault/GitHub/public key"}]}'
            ;;
          deploy-ssh)
            printf '%s\n' '{"id":"deploy-ssh","title":"Deploy SSH","fields":[{"label":"private key","reference":"op://Vault/Deploy/private key?ssh-format=openssh"}]}'
            ;;
          *)
            printf 'unexpected item id: %s\n' "$item_id" >&2
            exit 2
            ;;
        esac
        ;;
      *)
        printf 'unexpected op item subcommand: %s\n' "$subcommand" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    printf 'unexpected op command: %s\n' "$command" >&2
    exit 2
    ;;
esac
FAKE_OP
  chmod +x "$FAKE_BIN/op"
}

write_fake_jq() {
  cat >"$FAKE_BIN/jq" <<'FAKE_JQ'
#!/usr/bin/env bash
set -euo pipefail

query=""
label=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -r | -e)
      shift
      ;;
    --arg)
      [[ "${2:-}" == "label" ]] || exit 2
      label="${3:-}"
      shift 3
      ;;
    *)
      if [[ -z "$query" ]]; then
        query="$1"
      fi
      shift
      ;;
  esac
done

python3 -c 'import json, sys
query = sys.argv[1]
label = sys.argv[2]
data = json.load(sys.stdin)

if query == ".[] | [.id, .title] | @tsv":
    for item in data:
        print("{}\t{}".format(item["id"], item["title"]))
elif query == ".fields[]? | select(.label == $label) | .reference // empty":
    for field in data.get("fields", []):
        if field.get("label") == label and "reference" in field:
            print(field["reference"])
else:
    raise SystemExit(2)
' "$query" "$label"
FAKE_JQ
  chmod +x "$FAKE_BIN/jq"
}

write_fake_git() {
  cat >"$FAKE_BIN/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${GIT_LOG:?}"

if [[ "${1:-}" == "config" && "${2:-}" == "--global" ]]; then
  exit 0
fi

printf 'unexpected git args: %s\n' "$*" >&2
exit 2
FAKE_GIT
  chmod +x "$FAKE_BIN/git"
}

setup_home() {
  HOME_DIR="$TMP_DIR/$1"
  FAKE_BIN="$HOME_DIR/bin"
  GIT_LOG="$HOME_DIR/git.log"

  mkdir -p "$FAKE_BIN"
  : >"$GIT_LOG"

  export HOME="$HOME_DIR"
  export PATH="$FAKE_BIN:/usr/bin:/bin"
  export PRIVATE_KEY_CONTENT
  export PUBLIC_KEY_CONTENT
  export GIT_LOG

  write_fake_op
  write_fake_jq
  write_fake_git
}

file_mode() {
  stat -f '%Lp' "$1"
}

assert_git_was_configured() {
  local expected_key_path="$1"
  local log_content=""

  log_content="$(<"$GIT_LOG")"

  [[ "$log_content" == *"config --global user.signingkey $expected_key_path"* ]]
  [[ "$log_content" == *"config --global commit.gpgsign true"* ]]
  [[ "$log_content" == *"config --global tag.gpgsign true"* ]]
  [[ "$log_content" == *"config --global tag.forceSignAnnotated true"* ]]
  [[ "$log_content" == *"config --global gpg.format ssh"* ]]
  [[ "$log_content" == *"config --global --unset-all gpg.ssh.program"* ]]
}

assert_no_secret_output() {
  local output_file="$1"
  local error_file="$2"
  local output=""

  output="$(<"$output_file")$(<"$error_file")"
  [[ "$output" != *"$PRIVATE_KEY_CONTENT"* ]]
  [[ "$output" != *"$PUBLIC_KEY_CONTENT"* ]]
}

test_installs_key_without_git_by_default() {
  local output_file="$TMP_DIR/install.out"
  local error_file="$TMP_DIR/install.err"
  local key_path=""

  setup_home "install"
  key_path="$HOME_DIR/.ssh/id_ed25519"

  "$SCRIPT" --private-key-ref private-ref --public-key-ref public-ref >"$output_file" 2>"$error_file"

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ "$(<"$key_path.pub")" == "$PUBLIC_KEY_CONTENT" ]]
  [[ "$(file_mode "$HOME_DIR/.ssh")" == "700" ]]
  [[ "$(file_mode "$key_path")" == "600" ]]
  [[ "$(file_mode "$key_path.pub")" == "644" ]]

  [[ ! -s "$GIT_LOG" ]]
  assert_no_secret_output "$output_file" "$error_file"
}

test_explicit_git_signing_flag_updates_git() {
  local output_file="$TMP_DIR/signing-flag.out"
  local error_file="$TMP_DIR/signing-flag.err"
  local key_path=""

  setup_home "signing-flag"
  key_path="$HOME_DIR/.ssh/id_ed25519"

  "$SCRIPT" \
    --private-key-ref private-ref \
    --public-key-ref public-ref \
    --git-signing-key >"$output_file" 2>"$error_file"

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ "$(<"$key_path.pub")" == "$PUBLIC_KEY_CONTENT" ]]

  assert_git_was_configured "$key_path"
  assert_no_secret_output "$output_file" "$error_file"
}

test_interactive_default_name_path_prompts_and_installs_public_key() {
  local output_file="$TMP_DIR/interactive-default.out"
  local error_file="$TMP_DIR/interactive-default.err"
  local key_path=""

  setup_home "interactive-default"
  key_path="$HOME_DIR/.ssh/id_ed25519"

  printf '1\n\n\n' | "$SCRIPT" >"$output_file" 2>"$error_file"

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ "$(<"$key_path.pub")" == "$PUBLIC_KEY_CONTENT" ]]
  [[ "$(file_mode "$HOME_DIR/.ssh")" == "700" ]]
  [[ "$(file_mode "$key_path")" == "600" ]]
  [[ "$(file_mode "$key_path.pub")" == "644" ]]

  [[ ! -s "$GIT_LOG" ]]
  assert_no_secret_output "$output_file" "$error_file"
}

test_interactive_signing_confirmation_updates_git() {
  local output_file="$TMP_DIR/interactive-signing.out"
  local error_file="$TMP_DIR/interactive-signing.err"
  local key_path=""

  setup_home "interactive-signing"
  key_path="$HOME_DIR/.ssh/id_ed25519"

  printf '1\n\ny\n' | "$SCRIPT" >"$output_file" 2>"$error_file"

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ "$(<"$key_path.pub")" == "$PUBLIC_KEY_CONTENT" ]]

  assert_git_was_configured "$key_path"
  assert_no_secret_output "$output_file" "$error_file"
}

test_interactive_custom_name_path_uses_selected_item() {
  local output_file="$TMP_DIR/interactive-custom.out"
  local error_file="$TMP_DIR/interactive-custom.err"
  local key_path=""

  setup_home "interactive-custom"
  key_path="$HOME_DIR/.ssh/work_key"

  printf '2\nwork_key\nn\n' | "$SCRIPT" >"$output_file" 2>"$error_file"

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ ! -e "$key_path.pub" ]]
  [[ "$(file_mode "$HOME_DIR/.ssh")" == "700" ]]
  [[ "$(file_mode "$key_path")" == "600" ]]

  [[ ! -s "$GIT_LOG" ]]
  assert_no_secret_output "$output_file" "$error_file"
}

test_re_run_is_idempotent() {
  local key_path=""

  setup_home "idempotent"
  key_path="$HOME_DIR/.ssh/id_ed25519"

  "$SCRIPT" --private-key-ref private-ref --public-key-ref public-ref >/dev/null
  "$SCRIPT" --private-key-ref private-ref --public-key-ref public-ref >/dev/null

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ "$(file_mode "$key_path")" == "600" ]]
}

test_existing_different_key_requires_force() {
  local output_file="$TMP_DIR/mismatch.out"
  local error_file="$TMP_DIR/mismatch.err"
  local key_path=""

  setup_home "mismatch"
  key_path="$HOME_DIR/.ssh/id_ed25519"
  mkdir -p "$HOME_DIR/.ssh"
  printf '%s\n' 'different-key' >"$key_path"

  if "$SCRIPT" --private-key-ref private-ref >"$output_file" 2>"$error_file"; then
    printf 'expected different existing key to fail\n' >&2
    return 1
  fi

  [[ "$(<"$key_path")" == 'different-key' ]]
  assert_no_secret_output "$output_file" "$error_file"

  "$SCRIPT" --private-key-ref private-ref --force >/dev/null
  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
}

test_flags_can_set_key_name_and_skip_git() {
  local key_path=""

  setup_home "flags"
  key_path="$HOME_DIR/.ssh/work_key"

  "$SCRIPT" \
    --private-key-ref private-ref \
    --public-key-ref public-ref \
    --key-name work_key \
    --no-git >/dev/null

  [[ "$(<"$key_path")" == "$PRIVATE_KEY_CONTENT" ]]
  [[ "$(<"$key_path.pub")" == "$PUBLIC_KEY_CONTENT" ]]
  [[ ! -s "$GIT_LOG" ]]
}

tests=(
  test_installs_key_without_git_by_default
  test_explicit_git_signing_flag_updates_git
  test_interactive_default_name_path_prompts_and_installs_public_key
  test_interactive_signing_confirmation_updates_git
  test_interactive_custom_name_path_uses_selected_item
  test_re_run_is_idempotent
  test_existing_different_key_requires_force
  test_flags_can_set_key_name_and_skip_git
)

for test_name in "${tests[@]}"; do
  "$test_name"
  printf 'ok %s\n' "$test_name"
done
