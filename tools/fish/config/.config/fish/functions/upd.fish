function upd -d "updates different tools"
    argparse --max-args=0 -n upd h/help force -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: upd [--force] [--help]"
        printf '%s\n' ""
        printf '%s\n' "Update tools and run daily/weekly maintenance."
        printf '\n%s\n' Options
        printf '  %-12s %s\n' --force "run gated tasks now, bypassing daily/weekly limits"
        printf '  %-12s %s\n' --help "show this help"
        return
    end

    set -l state_dir "$HOME/.local/state/dotfiles/upd"
    if set -q XDG_STATE_HOME
        set state_dir "$XDG_STATE_HOME/dotfiles/upd"
    end

    if command -q brew
        set -l stamp_file "$state_dir/brew"
        set -l should_run_brew 1

        if not set -q _flag_force
            if test -f "$stamp_file"
                set -l last_brew (stat -f %m "$stamp_file")
                set -l now (date +%s)

                if test (math "$now - $last_brew") -lt 86400
                    set should_run_brew 0
                    echo "[upd] brew skipped, ran within the last day"
                end
            end
        end

        if test $should_run_brew -eq 1
            brew update
            and brew upgrade
            and brew autoremove
            and brew cleanup --prune=all
            and brew doctor
            and command mkdir -p "$state_dir"
            and command touch "$stamp_file"
        end
    else
        echo "[upd] brew not found, skipping"
    end

    if command -q mise
        mise upgrade --yes
        and mise prune --yes
    else
        echo "[upd] mise not found, skipping"
    end

    if command -q pnpm
        set -q PNPM_HOME; or set -gx PNPM_HOME "$HOME/Library/pnpm"
        mkdir -p "$PNPM_HOME"
        fish_add_path --append --path --move "$PNPM_HOME"
        pnpm -g update
    else
        echo "[upd] pnpm not found, skipping"
    end

    if command -q rustup
        rustup update
    else
        echo "[upd] rustup not found, skipping"
    end

    if command -q gh
        gh extension upgrade --all
    else
        echo "[upd] gh not found, skipping extension updates"
    end

    if command -q mas
        mas upgrade
    else
        echo "[upd] mas not found, skipping App Store updates"
    end

    if command -q nvim
        nvim --headless "+Lazy! sync" +qa
        nvim --headless "+lua require('config.treesitter').install()" +qa
    else
        echo "[upd] nvim not found, skipping"
    end

    if command -q mo
        set -l stamp_file "$state_dir/mo-clean"
        set -l should_run_clean 1

        if not set -q _flag_force
            if test -f "$stamp_file"
                set -l last_clean (stat -f %m "$stamp_file")
                set -l now (date +%s)

                if test (math "$now - $last_clean") -lt 604800
                    set should_run_clean 0
                    echo "[upd] mo clean skipped, ran within the last week"
                end
            end
        end

        if test $should_run_clean -eq 1
            mo clean
            and command mkdir -p "$state_dir"
            and command touch "$stamp_file"
        end
    else
        echo "[upd] mo not found, skipping"
    end

    if test -d "$HOME/.cache/opencode"
        echo "[upd] removing OpenCode cache"
        rm -rf "$HOME/.cache/opencode"
    end

    if command -q bunx
        if bunx skills list -g
            bunx skills update --yes
        else
            echo "[upd] unable to list skills, skipping skills update"
        end
    else
        echo "[upd] bunx not found, skipping skills update"
    end

    # Fish plugin update should be at the end of the function.
    if type -q fisher; and test -f "$__fish_config_dir/fish_plugins"
        set -l fish_path (status fish-path)
        set -l fisher_file "$__fish_config_dir/functions/fisher.fish"

        if test -f "$fisher_file"
            "$fish_path" --no-config --command "source \"$fisher_file\"; and fisher update"
        else
            "$fish_path" --command "fisher update"
        end
    else if type -q fisher
        echo "[upd] fish_plugins not found, skipping fisher update"
    else
        echo "[upd] fisher not found, skipping fisher update"
    end
end
