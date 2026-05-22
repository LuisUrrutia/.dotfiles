function upd -d "updates different tools"
    if command -q brew
        brew update
        and brew upgrade
        and brew autoremove
        and brew cleanup --prune=all
        and brew doctor
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
        mo clean
    else
        echo "[upd] mo not found, skipping"
    end

    if test -d "$HOME/.cache/opencode"
        echo "[upd] removing OpenCode cache"
        rm -rf "$HOME/.cache/opencode"
    end

    if command -q bunx
        if bunx skills list -g
            bunx skills update
        else
            echo "[upd] unable to list skills, skipping skills update"
        end
    else
        echo "[upd] bunx not found, skipping skills update"
    end

    # Fish plugin update should be at the end of the function.
    if type -q fisher; and test -f "$__fish_config_dir/fish_plugins"
        fisher update
    else if type -q fisher
        echo "[upd] fish_plugins not found, skipping fisher update"
    else
        echo "[upd] fisher not found, skipping fisher update"
    end
end
