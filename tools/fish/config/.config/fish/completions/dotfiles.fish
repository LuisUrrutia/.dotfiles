complete --erase -c dotfiles
complete -c dotfiles -f

function __dotfiles_seen_subcommand -a subcommand -d "Check the active Dotfiles command"
    contains -- $subcommand (commandline --current-process --tokenize --cut-at-cursor)
end

function __dotfiles_needs_group_command -a group -d "Check whether a Dotfiles group needs a command"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 2; and test "$tokens[2]" = "$group"
end

function __dotfiles_needs_tool_name -d "Check whether Tool Apply needs a tool name"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 3; and test "$tokens[2]" = tool; and test "$tokens[3]" = apply
end


function __dotfiles_needs_config_tool -d "Check whether a Config command needs a tool"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 3; or return 1
    test "$tokens[2]" = config; or return 1
    contains -- "$tokens[3]" status diff repair capture discard resolve
end

function __dotfiles_needs_config_path -d "Check whether a Config command accepts a path"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 4; or return 1
    test "$tokens[2]" = config; or return 1
    contains -- "$tokens[3]" diff repair capture discard resolve
end

function __dotfiles_needs_help_command -d "Check whether Help needs a public command"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 2; and test "$tokens[2]" = help
end

function __dotfiles_needs_help_child -a group -d "Check whether Help needs a nested command"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 3; and test "$tokens[2]" = help; and test "$tokens[3]" = "$group"
end

function __dotfiles_needs_backup_target -d "Check whether Backup needs a target"
    set -l tokens (commandline --current-process --tokenize --cut-at-cursor)
    test (count $tokens) -eq 2; and test "$tokens[2]" = backup
end

function __dotfiles_tools -d "List safe Tool Catalog candidates"
    command dotfiles tool list 2>/dev/null
end

function __dotfiles_repository_root -d "Find the repository behind the installed Dotfiles command"
    set -l executable (type -P dotfiles 2>/dev/null)
    test -n "$executable"; or return 1
    set executable (path resolve "$executable" 2>/dev/null)

    set -l candidate (path dirname "$executable")
    for depth in (seq 1 7)
        if test -x "$candidate/dotfiles"; and test -d "$candidate/tools"
            echo "$candidate"
            return 0
        end
        set candidate (path dirname "$candidate")
    end
    return 1
end

function __dotfiles_config_tools -d "List tools with tracked Stowed Config"
    set -l root (__dotfiles_repository_root); or return
    for tool_dir in "$root"/tools/*/config
        test -d "$tool_dir"; or continue
        set -l tool (path basename (path dirname "$tool_dir"))
        git -C "$root" ls-files --error-unmatch "tools/$tool/config" >/dev/null 2>&1; and echo "$tool"
    end
end

function __dotfiles_config_paths -a tool -d "List tracked eligible Config paths"
    string match -rq '^[A-Za-z0-9][A-Za-z0-9._-]*$' -- "$tool"; or return
    set -l root (__dotfiles_repository_root); or return
    set -l prefix "tools/$tool/config/"
    set -l ignore_file "$root/tools/$tool/config/.stow-local-ignore"
    set -l patterns
    if test -f "$ignore_file"
        set patterns (string match -rv '^\s*(#|$)' <"$ignore_file")
    end

    for tracked in (git -C "$root" ls-files "$prefix" 2>/dev/null)
        set -l relative (string replace "$prefix" '' -- "$tracked")
        test -n "$relative"; or continue
        test -f "$root/$tracked"; or continue
        test -L "$root/$tracked"; and continue
        test "$relative" = .stow-local-ignore; and continue
        set -l ignored false
        for pattern in $patterns
            if string match -rq -- "$pattern" "/$relative"
                set ignored true
                break
            end
        end
        test "$ignored" = false; and echo "$relative"
    end
end

# Root grammar.
complete -c dotfiles -f -n __fish_use_subcommand -a install -d "Bootstrap this Mac"
complete -c dotfiles -f -n __fish_use_subcommand -a tool -d "List or apply Tool Installers"
complete -c dotfiles -f -n __fish_use_subcommand -a verify -d "Run verification"
complete -c dotfiles -f -n __fish_use_subcommand -a config -d "Manage Stowed Config drift"
complete -c dotfiles -f -n __fish_use_subcommand -a update -d "Update installed software"
complete -c dotfiles -f -n __fish_use_subcommand -a backup -d "Back up application configuration"
complete -c dotfiles -f -n __fish_use_subcommand -a help -d "Show contextual help"
complete -c dotfiles -s h -l help -d "Show help"
complete -c dotfiles -f -n __dotfiles_needs_help_command -a 'install tool verify config update backup'
complete -c dotfiles -f -n '__dotfiles_needs_help_child tool' -a 'list apply'
complete -c dotfiles -f -n '__dotfiles_needs_help_child config' -a 'status diff repair capture discard resolve'
complete -c dotfiles -f -n '__dotfiles_needs_help_child backup' -a 'all raycast thaw'

# Install.
complete -c dotfiles -n '__dotfiles_seen_subcommand install' -s n -l dry-run -d "Preview without changing the system"
complete -c dotfiles -n '__dotfiles_seen_subcommand install' -l core-only -d "Install only core packages"
complete -c dotfiles -n '__dotfiles_seen_subcommand install' -l all-profiles -d "Install all optional profiles"
complete -c dotfiles -n '__dotfiles_seen_subcommand install' -l no-upgrade -d "Skip Homebrew update and upgrade"
complete -c dotfiles -n '__dotfiles_seen_subcommand install' -l profile -r -a '(path basename (__dotfiles_repository_root)/brewfiles/profiles/*)' -d "Install selected profiles"

# Tool Catalog.
complete -c dotfiles -f -n '__dotfiles_needs_group_command tool' -a list -d "List Tool Installers"
complete -c dotfiles -f -n '__dotfiles_needs_group_command tool' -a apply -d "Run one Tool Installer"
complete -c dotfiles -f -n __dotfiles_needs_tool_name -a '(__dotfiles_tools)'

# Verification and Config Lifecycle.
complete -c dotfiles -f -n '__dotfiles_needs_group_command config' -a status -d "Classify Config state"
complete -c dotfiles -f -n '__dotfiles_needs_group_command config' -a diff -d "Show Config drift"
complete -c dotfiles -f -n '__dotfiles_needs_group_command config' -a repair -d "Restore safe links"
complete -c dotfiles -f -n '__dotfiles_needs_group_command config' -a capture -d "Capture a live file"
complete -c dotfiles -f -n '__dotfiles_needs_group_command config' -a discard -d "Discard a live file"
complete -c dotfiles -f -n '__dotfiles_needs_group_command config' -a resolve -d "Resolve drift with an agent"
complete -c dotfiles -f -n __dotfiles_needs_config_tool -a '(__dotfiles_config_tools)'
complete -c dotfiles -f -n __dotfiles_needs_config_path -a '(__dotfiles_config_paths (commandline --current-process --tokenize)[4])'
complete -c dotfiles -n '__dotfiles_seen_subcommand repair; or __dotfiles_seen_subcommand capture; or __dotfiles_seen_subcommand discard' -l dry-run -d "Preview the action"
complete -c dotfiles -n '__dotfiles_seen_subcommand resolve' -l agent -r -a 'claude codex' -d "Choose the resolution agent"

# Phase 3.
complete -c dotfiles -n '__dotfiles_seen_subcommand update' -l ignore-schedule -d "Bypass daily and weekly gates"
complete -c dotfiles -f -n __dotfiles_needs_backup_target -a 'all raycast thaw'
