function skill-link -d "Link a skill directory into the agent skill directories"
    set -l source_argument

    for arg in $argv
        switch $arg
            case -h --help
                echo "Usage: skill-link [directory]"
                echo "  directory        Skill directory holding a SKILL.md (default: .)"
                echo "  -h, --help       Show this help message"
                echo ""
                echo "Replaces the installed copy in ~/.agents/skills and ~/.claude/skills"
                echo "with a symlink to the directory. An installed copy that differs is"
                echo "moved to ~/.agents/skills-backups first."
                return 0
            case '-*'
                echo "skill-link: unknown option '$arg'" >&2
                return 1
            case '*'
                if test -n "$source_argument"
                    echo "skill-link: expected exactly one directory" >&2
                    return 1
                end
                set source_argument $arg
        end
    end

    test -n "$source_argument"; or set source_argument .

    if not test -d "$source_argument"
        echo "skill-link: not a directory: $source_argument" >&2
        return 1
    end

    set -l source (path resolve "$source_argument")

    if not test -f "$source/SKILL.md"
        echo "skill-link: no SKILL.md in $source" >&2
        return 1
    end

    set -l agent_dirs (skill_agent_dirs)

    for agent_dir in $agent_dirs
        if string match -q "$agent_dir/*" -- "$source"
            echo "skill-link: $source is already an installed skill" >&2
            return 1
        end
    end

    set -l name (path basename "$source")
    set -l failed false

    for agent_dir in $agent_dirs
        if not __skill_link_into "$name" "$source" "$agent_dir"
            set failed true
        end
    end

    test "$failed" = false
end

function __skill_link_into -a name source agent_dir -d "Point one agent directory at a skill"
    set -l target "$agent_dir/$name"

    mkdir -p "$agent_dir"; or return 1

    if test -L "$target"
        set -l current (readlink "$target")

        if test "$current" = "$source"
            echo "Already linked $target"
            return 0
        end

        if __skill_link_is_replaceable "$target" "$source"
            rm "$target"; or return 1
        else
            __skill_link_backup "$target" "$agent_dir"; or return 1
        end
    else if test -d "$target"
        if diff -rq -x .git -x .omo -x .DS_Store "$source" "$target" >/dev/null 2>&1
            rm -rf "$target"; or return 1
        else
            __skill_link_backup "$target" "$agent_dir"; or return 1
        end
    else if test -e "$target"
        __skill_link_backup "$target" "$agent_dir"; or return 1
    end

    ln -s "$source" "$target"; or return 1
    echo "Linked $target -> $source"
end

# The skills CLI chains one agent directory to another, so such a link holds
# nothing the source does not. Any other symlink is someone else's and is kept.
function __skill_link_is_replaceable -a target source -d "Check whether a symlink can be dropped"
    set -l resolved (path resolve "$target")

    test "$resolved" = "$source"; and return 0

    for agent_dir in (skill_agent_dirs)
        string match -q "$agent_dir/*" -- "$resolved"; and return 0
    end

    return 1
end

function __skill_link_backup -a target agent_dir -d "Move an installed skill aside"
    set -l agent (path basename (path dirname "$agent_dir"))
    set -l name (path basename "$target")
    set -l destination "$HOME/.agents/skills-backups/"(string replace -r '^\.' '' $agent)"/$name-"(date +%Y%m%d-%H%M%S)
    set -l parent (path dirname "$destination")

    mkdir -p "$parent"; or return 1
    mv "$target" "$destination"; or return 1
    echo "Backed up $target to $destination"
end
