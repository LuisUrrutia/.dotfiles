complete --erase -c wtpr

function __fish_wtpr_prs
    command -q gh; and command -q jq; or return
    gh pr list --limit 100 --json number,title 2>/dev/null | jq -r '.[] | "#\(.number)\t\(.title)"' 2>/dev/null
end

complete -c wtpr -f -a '(__fish_wtpr_prs)' -d "GitHub PR number"
