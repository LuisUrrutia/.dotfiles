command -q mise; or return
set -l directory (mise where bun 2>/dev/null); or return
test -f "$directory/mise-completions/bun.fish"; and source "$directory/mise-completions/bun.fish"
