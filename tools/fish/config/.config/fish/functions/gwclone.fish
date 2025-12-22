function gwclone -d "Git clone for worktree"
    # Usage: gwclone <repo-url> [folder-name]
    if test (count $argv) -lt 1 -o (count $argv) -gt 2
        echo "Usage: gwclone <repo-url> [folder-name]"
        return 1
    end

    set -l repo_url $argv[1]

    # Extract repo name from URL
    # Handles both SSH (git@github.com:user/repo.git) and HTTPS (https://github.com/user/repo.git)
    set -l repo_name (string replace -r '.*[:/]([^/]+?)(?:\.git)?$' '$1' $repo_url)
    set -l default_branch (git ls-remote --symref $repo_url HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}')

    echo "Repository name detected: $repo_name"

    # Use custom folder name if provided, otherwise use repo name
    if test (count $argv) -eq 2
        set folder_name $argv[2]
    else
        set folder_name $repo_name
    end

    echo "Cloning $repo_url into $folder_name as a worktree..."

    mkdir -p $folder_name
    and cd $folder_name
    and git clone $repo_url $default_branch
end