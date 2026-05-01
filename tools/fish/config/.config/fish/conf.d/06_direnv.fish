status is-interactive; or return

if command -q direnv
    function __direnv_export_eval --on-event fish_prompt
        set -l projects_dir "$HOME/Projects"

        if string match -q -- "$projects_dir" "$PWD"; or string match -q -- "$projects_dir/*" "$PWD"
            direnv export fish | source
            return
        end

        set -l current_dir "$PWD"
        builtin cd /
        direnv export fish | source
        builtin cd "$current_dir"
    end
end
