function prs -d "Show current GitHub PR status"
    if not command -q gh
        echo "Error: gh is required" >&2
        return 1
    end

    if not command -q jq
        echo "Error: jq is required" >&2
        return 1
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Error: not in a git repository" >&2
        return 1
    end

    set -l json (gh pr view --json number,title,url,state,isDraft,reviewDecision 2>&1)
    if test $status -ne 0
        printf '%s\n' $json >&2
        return 1
    end

    set -l pr_status (printf '%s\n' $json | jq -r '
        if .state == "MERGED" then "merged"
        elif .state == "CLOSED" then "closed"
        elif .isDraft == true then "draft"
        elif .reviewDecision == "APPROVED" then "approved"
        elif .reviewDecision == "CHANGES_REQUESTED" then "changes requested"
        elif .reviewDecision == "REVIEW_REQUIRED" then "review required"
        else "open"
        end
    ')
    set -l number (printf '%s\n' $json | jq -r '.number')
    set -l title (printf '%s\n' $json | jq -r '.title')
    set -l url (printf '%s\n' $json | jq -r '.url')

    printf '#%s %s [%s]\n%s\n' $number $title $pr_status $url
end
