function wtpr -d "Open a GitHub PR in a WorkTrunk worktree"
    if not command -q wt
        echo "Error: wt is required" >&2
        return 1
    end

    if test (count $argv) -gt 0
        if test (count $argv) -ne 1
            echo "Error: pass a PR number or URL" >&2
            return 1
        end

        set -l pr_input $argv[1]
        set -l pr

        if string match -qr '^[0-9]+$' -- "$pr_input"
            set pr $pr_input
        else
            set pr (string replace -r '^https://github\.com/[^/]+/[^/]+/pull/([0-9]+)([/#?].*)?$' '$1' -- "$pr_input")
        end

        if test -z "$pr"; or not string match -qr '^[0-9]+$' -- "$pr"
            echo "Error: pass a PR number or GitHub PR URL" >&2
            return 1
        end

        wt switch "pr:$pr"
        return $status
    end

    if not command -q gh
        echo "Error: gh is required" >&2
        return 1
    end

    if not command -q jq
        echo "Error: jq is required" >&2
        return 1
    end

    if not command -q fzf
        echo "Error: fzf is required" >&2
        return 1
    end

    set -l selection (gh pr list --limit 100 --json number,title,author,headRefName,updatedAt | jq -r '.[] | "#\(.number)	\(.headRefName)	\(.author.login)	\(.title)"' | fzf --prompt='PR> ' --delimiter='	' --with-nth='1,2,4' --preview='fish -c "gh pr view (string replace \"#\" \"\" -- {1}) --comments"')
    test -n "$selection"; or return 130

    set -l pr (string replace '#' '' -- (printf '%s\n' "$selection" | cut -f1))
    wt switch "pr:$pr"
end
