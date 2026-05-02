function glogf -d "Pick a Git commit with fzf and show it"
    if test (count $argv) -gt 0
        git log $argv
        return $status
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Error: not in a git repository" >&2
        return 1
    end

    if not command -q fzf
        echo "Error: fzf is required" >&2
        return 1
    end

    set -l preview_cmd 'git show --color=always --format=medium --stat --patch {1}'
    if command -q delta
        set preview_cmd "$preview_cmd | delta --paging=never --width=20"
    end

    set -l selection (git log --date=short --format='%h %ad %d %s [%an]' | fzf --no-sort --scheme=history --prompt='Git Log> ' --preview="$preview_cmd")
    test -n "$selection"; or return 130

    set -l commit (string split --max 1 ' ' -- $selection)[1]
    git show --format=medium $commit
end
