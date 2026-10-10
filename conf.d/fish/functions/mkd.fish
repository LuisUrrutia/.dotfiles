function mkd -d "Create a directory and set CWD"
    argparse -n mkd h/help -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: mkd <directory>"
        printf '%s\n' "Create a directory and cd into it."
        return 0
    end

    if test (count $argv) -ne 1
        echo "Usage: mkd <directory>" >&2
        return 1
    end

    set -l target $argv[1]

    command mkdir -p -- "$target"
    or return $status

    if test -d "$target"
        cd "$target"
        return $status
    end

    return 1
end
