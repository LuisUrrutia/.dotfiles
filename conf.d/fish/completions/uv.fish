command -q mise; or return
set -l directory (mise where uv 2>/dev/null); or return
test -f "$directory/mise-completions/uv.fish"; and source "$directory/mise-completions/uv.fish"
