function skill-unlink -d "Remove development links from the agent skill directories"
    set -l source_arguments

    for arg in $argv
        switch $arg
            case -h --help
                echo "Usage: skill-unlink [directory ...]"
                echo "  directory        Linked skill directory (default: .)"
                echo "  -h, --help       Show this help message"
                echo ""
                echo "Removes only symlinks in ~/.agents/skills and ~/.claude/skills"
                echo "that resolve to the directory. Installed copies, unrelated symlinks,"
                echo "and backups are left unchanged."
                return 0
            case '-*'
                echo "skill-unlink: unknown option '$arg'" >&2
                return 1
            case '*'
                set -a source_arguments "$arg"
        end
    end

    test (count $source_arguments) -gt 0; or set source_arguments .

    set -l failed false

    for source_argument in $source_arguments
        if not __skill_unlink_one "$source_argument"
            set failed true
        end
    end

    test "$failed" = false
end

function __skill_unlink_one -a source_argument -d "Remove development links for one skill directory"

    if not test -d "$source_argument"
        echo "skill-unlink: not a directory: $source_argument" >&2
        return 1
    end

    set -l source (path resolve "$source_argument")
    set -l name (path basename "$source")
    set -l linked_targets

    for agent_dir in (skill_agent_dirs)
        set -l target "$agent_dir/$name"

        if not test -L "$target"
            if test -e "$target"
                echo "Preserved $target: not a symlink"
            else
                echo "Not linked $target"
            end
            continue
        end

        set -l resolved (path resolve "$target" 2>/dev/null)

        if test "$resolved" = "$source"
            set -a linked_targets "$target"
        else
            echo "Preserved $target: points to "(readlink "$target")
        end
    end

    set -l failed false

    for target in $linked_targets
        if rm "$target"
            echo "Unlinked $target"
        else
            set failed true
        end
    end

    test "$failed" = false
end
