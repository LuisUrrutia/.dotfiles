command -q mise; or return
set -l directory (mise where zoxide 2>/dev/null); or return
test -f "$directory/completions/zoxide.fish"; and source "$directory/completions/zoxide.fish"
