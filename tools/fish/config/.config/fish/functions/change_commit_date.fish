function change_commit_date -d "Change the date of the most recent commit"
    if test (count $argv) -ne 1
        echo "Usage: change_commit_date <date>"
        echo "Example: change_commit_date '2023-12-25 10:30:00'"
        echo "Example: change_commit_date '-2h'"
        echo "Example: change_commit_date '-30m'"
        return 1
    end

    command -q git; or begin
        echo "Error: git not found."
        return 1
    end
    command -q gdate; or begin
        echo "Error: gdate not found. Install coreutils."
        return 1
    end

    git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null; or begin
        echo "Error: not inside a Git repository."
        return 1
    end

    set -l date_string $argv[1]
    set -l git_date (gdate -d "$date_string" --rfc-email 2>/dev/null)

    if test $status -ne 0; or test -z "$git_date"
        echo "Error: invalid date format '$date_string'"
        return 1
    end

    set -lx GIT_AUTHOR_DATE "$git_date"
    set -lx GIT_COMMITTER_DATE "$git_date"

    echo "Changing date to $git_date"
    git commit --amend --no-edit --date "$git_date"
end
