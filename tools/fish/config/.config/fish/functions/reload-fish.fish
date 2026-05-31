function reload-fish -d "Reload the current Fish session"
    argparse -n reload-fish h/help f/force -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: reload-fish [--force] [--help]"
        printf '%s\n' ""
        printf '%s\n' "Reload the current Fish process with config re-sourced."
        printf '\n%s\n' Options
        printf '  %-12s %s\n' --force "reload even when background jobs are running"
        printf '  %-12s %s\n' --help "show this help"
        return
    end

    if test (count $argv) -ne 0
        echo "Usage: reload-fish [--force] [--help]" >&2
        return 1
    end

    if not set -q _flag_force
        set -l job_pids (jobs --pid)
        if test (count $job_pids) -gt 0
            echo "reload-fish: refusing to reload with background jobs running" >&2
            jobs >&2
            echo "reload-fish: rerun with --force to replace this shell anyway" >&2
            return 1
        end
    end

    history save 2>/dev/null

    set -l init_commands 'function fish_greeting; end'
    for variable_name in dirprev dirnext dirstack
        if set -q $variable_name
            set -l values $$variable_name
            set -a init_commands (string join ' ' -- set -g $variable_name (string escape -- $values))
        end
    end

    exec fish -C (string join '; ' -- $init_commands)
end
