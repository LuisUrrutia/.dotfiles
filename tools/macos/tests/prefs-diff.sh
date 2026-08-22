#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT_DIR/tools/macos/prefs-diff.sh"

fail() {
  printf 'prefs-diff test: %s\n' "$*" >&2
  exit 1
}

fixture_home="$(mktemp -d)"
trap 'rm -rf "$fixture_home"' EXIT

prefs_dir="$fixture_home/Library/Preferences"
mkdir -p "$prefs_dir"

cat >"$prefs_dir/com.example.readable.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>SomeKey</key>
    <string>SomeValue</string>
  </dict>
</plist>
PLIST

# A plist that cannot be parsed at all. Two of these ship with Photoshop, and
# they used to abort the entire listing rather than being reported as one row.
printf 'not a plist at all' >"$prefs_dir/com.example.broken.plist"

# A plist whose root is an array rather than a dictionary, which takes the
# other early-return path out of the per-file loop
cat >"$prefs_dir/com.example.rootarray.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <string>one</string>
  </array>
</plist>
PLIST

# Both early-return rows carry a path, so they are the ones that overrun the
# column widths; every flag combination has to keep the row and column counts
# in step
for flags in "" "--values" "--paths" "--values --paths" "--include-noisy"; do
  # shellcheck disable=SC2086
  if ! output="$(HOME="$fixture_home" /bin/bash "$SCRIPT" $flags 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "prefs-diff.sh exited non-zero with flags '${flags:-<none>}'"
  fi

  [[ "$output" == *"<unreadable>"* ]] ||
    fail "an unparseable plist was dropped instead of reported with flags '${flags:-<none>}'"
  [[ "$output" == *"<root>"* ]] ||
    fail "a non-dictionary plist root was dropped with flags '${flags:-<none>}'"
  [[ "$output" == *"com.example.readable"* ]] ||
    fail "a readable plist was lost with flags '${flags:-<none>}'"
done

# The header names the columns, so it is what every row has to line up with
header="$(HOME="$fixture_home" /bin/bash "$SCRIPT" --values --paths | head -1)"
[[ "$(printf '%s\n' "$header" | wc -w | tr -d ' ')" -eq 6 ]] ||
  fail "--values --paths did not produce all six columns"

printf 'prefs-diff test: passed\n'
