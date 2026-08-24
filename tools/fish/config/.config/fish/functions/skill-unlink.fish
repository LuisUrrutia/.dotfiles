function skill-unlink -d "Remove development links from the agent skill directories"
    set -l source_argument

    for arg in $argv
        switch $arg
            case -h --help
                echo "Usage: skill-unlink [directory]"
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
                if test -n "$source_argument"
                    echo "skill-unlink: expected exactly one directory" >&2
                    return 1
                end
                set source_argument $arg
        end
    end

    test -n "$source_argument"; or set source_argument .

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
