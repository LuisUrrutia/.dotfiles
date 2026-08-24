complete --erase --command claude

if command -q claude
    set -l section

    command claude --help 2>/dev/null | while read -l line
        switch $line
            case Options:
                set section options
            case Commands:
                set section commands
            case '  -*'
                test "$section" = options; or continue

                set -l fields (string split -m 1 '  ' -- (string replace -r '^  ' '' -- $line))
                set -l signature $fields[1]
                set -l description (string trim -- "$fields[2]")
                set -l definition -c claude -n __fish_use_subcommand

                for option in (string match -ra -- '-{1,2}[[:alnum:]][[:alnum:]-]*' "$signature")
                    if string match -q -- '--*' $option
                        set -a definition -l (string sub -s 3 -- $option)
                    else
                        set -a definition -s (string sub -s 2 -- $option)
                    end
                end

                if string match -q -- '*<*>' "$signature"
                    set -a definition -r
                else
                    set -a definition -f
                end
                test -z "$description"; or set -a definition -d "$description"

                complete $definition
            case '  *'
                test "$section" = commands; or continue

                set -l command_line (string replace -r '^  ' '' -- $line)
                string match -rq -- '^[a-z]' "$command_line"; or continue

                set -l fields (string split -m 1 '  ' -- $command_line)
                set -l signature (string split -m 1 ' ' -- $fields[1])
                set -l description (string trim -- "$fields[2]")

                for subcommand in (string split '|' -- $signature[1])
                    set -l definition -c claude -n __fish_use_subcommand -f -a $subcommand
                    test -z "$description"; or set -a definition -d "$description"
                    complete $definition
                end
        end
    end
end

# Claude omits documented options from --help: https://code.claude.com/docs/en/cli-reference
complete -c claude -n __fish_use_subcommand -l advisor -r -a "fable opus sonnet" -d "Select the advisor model"
complete -c claude -n __fish_use_subcommand -l append-subagent-system-prompt -r -d "Append to every subagent system prompt"
complete -c claude -n __fish_use_subcommand -l append-system-prompt-file -rF -d "Append a file to the system prompt"
complete -c claude -n __fish_use_subcommand -l channels -r -d "Listen to MCP channels"
complete -c claude -n __fish_use_subcommand -l dangerously-load-development-channels -r -d "Load development channels outside the allowlist"
complete -c claude -n __fish_use_subcommand -l exec -r -d "Run a background shell command"
complete -c claude -n __fish_use_subcommand -l init -f -d "Run init setup hooks"
complete -c claude -n __fish_use_subcommand -l init-only -f -d "Run setup hooks and exit"
complete -c claude -n __fish_use_subcommand -l maintenance -f -d "Run maintenance setup hooks"
complete -c claude -n __fish_use_subcommand -l max-turns -r -d "Limit agentic turns"
complete -c claude -n __fish_use_subcommand -l permission-prompt-tool -r -d "Delegate permission prompts to an MCP tool"
complete -c claude -n __fish_use_subcommand -l rc -f -d "Enable Remote Control"
complete -c claude -n __fish_use_subcommand -l ref -r -d "Select the base ref for a cloud environment"
complete -c claude -n __fish_use_subcommand -l remote -f -d "Use the deprecated cloud alias"
complete -c claude -n __fish_use_subcommand -l system-prompt-file -rF -d "Replace the system prompt from a file"
complete -c claude -n __fish_use_subcommand -l teammate-mode -r -a "in-process auto tmux iterm2" -d "Select how teammates display"
