function gwnb -d "Git worktree new branch"
    if test (count $argv) -ne 1
        echo "Usage: gwnb <new-branch-name>"
        return 1
    end

    set -l branch_name $argv[1]
    set -l folder_name (basename $branch_name)
    set -l worktree_path "../$folder_name"

    git worktree add $worktree_path -b $branch_name
    and echo "git worktree add $worktree_path -b $branch_name"
    and echo "Created new worktree at $worktree_path for branch '$branch_name'"
    and cd $worktree_path
end

