function __fish_doctor_ok
    printf '[ok] %s\n' "$argv"
end

function __fish_doctor_warn
    printf '[warn] %s\n' "$argv"
end

function __fish_doctor_fail
    printf '[fail] %s\n' "$argv"
end

function fish-doctor -d "Check Fish dotfiles health"
    argparse --max-args=0 -n fish-doctor h/help -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: fish-doctor [--help]"
        printf '%s\n' ""
        printf '%s\n' "Run safe checks for this Fish configuration."
        printf '\n%s\n' Checks
        printf '  %s\n' "syntax for config.fish, conf.d, functions, and completions"
        printf '  %s\n' "quiet noninteractive startup"
        printf '  %s\n' "expected Fish integrations and optional tools"
        printf '\n%s\n' Options
        printf '  %-12s %s\n' --help "show this help"
        return
    end

    set -l function_file (status --current-filename)
    set -l fish_root (dirname (dirname "$function_file"))
    set -l config_home (dirname "$fish_root")
    set -l fish_env XDG_CONFIG_HOME="$config_home" TERM_PROGRAM=vscode
    set -l failed 0

    printf '%s\n' "Fish root: $fish_root"
    printf '\n%s\n' Syntax

    set -l syntax_files "$fish_root/config.fish"
    for directory in conf.d functions completions
        if test -d "$fish_root/$directory"
            for file in "$fish_root/$directory"/*.fish
                test -f "$file"; and set -a syntax_files "$file"
            end
        end
    end

    for file in $syntax_files
        set -l relative_file (string replace -- "$fish_root/" '' "$file")
        if command fish -n "$file" >/dev/null 2>&1
            __fish_doctor_ok "syntax $relative_file"
        else
            __fish_doctor_fail "syntax $relative_file"
            command fish -n "$file"
            set failed 1
        end
    end

    printf '\n%s\n' Startup
    set -l startup_output (env $fish_env fish -c true 2>&1)
    if test -z "$startup_output"
        __fish_doctor_ok "noninteractive startup is quiet"
    else
        __fish_doctor_fail "noninteractive startup printed output"
        printf '%s\n' $startup_output
        set failed 1
    end

    printf '\n%s\n' Integrations
    if test -f "$fish_root/fish_plugins"
        __fish_doctor_ok "fish_plugins manifest exists"
    else
        __fish_doctor_warn "fish_plugins manifest not found"
    end

    if env $fish_env fish -c 'contains -- "$__fish_config_dir/completions" $fish_complete_path' >/dev/null 2>&1
        __fish_doctor_ok "user completions are in fish_complete_path"
    else
        __fish_doctor_warn "user completions are missing from fish_complete_path"
    end

    if env $fish_env fish -ic 'type -q fisher; and fisher list >/dev/null' >/dev/null 2>&1
        __fish_doctor_ok "Fisher is available"
    else
        __fish_doctor_warn "Fisher is not loaded in this config home"
    end

    if env $fish_env fish -ic 'command -q starship; and functions -q fish_prompt' >/dev/null 2>&1
        __fish_doctor_ok "Starship prompt is available"
    else
        __fish_doctor_warn "Starship prompt is not available"
    end

    if command -q fzf
        if printf '%s\n' one two | fzf --filter one >/dev/null 2>&1
            __fish_doctor_ok "fzf filter mode works"
        else
            __fish_doctor_warn "fzf command exists but filter probe failed"
        end
    else
        __fish_doctor_warn "fzf command not found"
    end

    if env $fish_env fish -ic 'functions -q _fzf_search_history; and functions -q fzf_configure_bindings' >/dev/null 2>&1
        __fish_doctor_ok "fzf.fish functions are loaded"
    else
        __fish_doctor_warn "fzf.fish functions are not loaded in this config home"
    end

    if env $fish_env fish -ic 'command -q zoxide; and functions -q z; and functions -q zi; and functions -q _zoxide_cd; and functions cd | string match -q "*z \$argv*"' >/dev/null 2>&1
        __fish_doctor_ok "zoxide cd integration is loaded"
    else
        __fish_doctor_warn "zoxide cd integration is not loaded"
    end

    if command -q atuin
        atuin --version >/dev/null 2>&1
        and __fish_doctor_ok "atuin command is available"
        or __fish_doctor_warn "atuin command exists but version probe failed"
    else
        __fish_doctor_warn "atuin command not found"
    end

    if command -q mise
        mise --version >/dev/null 2>&1
        and __fish_doctor_ok "mise command is available"
        or __fish_doctor_warn "mise command exists but version probe failed"
    else
        __fish_doctor_warn "mise command not found"
    end

    if test $failed -eq 0
        printf '\n%s\n' "fish-doctor: ok"
        return 0
    end

    printf '\n%s\n' "fish-doctor: failed"
    return 1
end
