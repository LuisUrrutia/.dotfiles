function change_commit_date -d "Change the date of the most recent commit"
    if test (count $argv) -eq 0
        echo "Usage: change_commit_date <date>"
        echo "Example: change_commit_date '2023-12-25 10:30:00'"
        echo "Example: change_commit_date '-2h'"
        echo "Example: change_commit_date '-30m'"
        return 1
    end

    set date_string $argv[1]
    set git_date (gdate -d"$date_string" --rfc-email)
    
    if test $status -ne 0
        echo "Error: Invalid date format '$date_string'"
        return 1
    end

    set -x GIT_AUTHOR_DATE $git_date
    set -x GIT_COMMITTER_DATE $git_date

    echo "Changing date to $git_date"
    git commit --amend --no-edit --date "$git_date"
    
    # Clean up environment variables
    set -e GIT_AUTHOR_DATE
    set -e GIT_COMMITTER_DATE
end
