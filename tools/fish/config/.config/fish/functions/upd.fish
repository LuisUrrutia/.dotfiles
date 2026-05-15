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

    if command -q fnm
        fnm install --lts --use --corepack-enabled
        fnm default lts-latest
    else
        echo "[upd] fnm not found, skipping"
    end

    if command -q corepack
        corepack enable
        corepack prepare pnpm@latest --activate
    else
        echo "[upd] corepack not found, skipping"
    end

    if command -q pnpm
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

    # Fish plugin update should be at the end of the function.
    if type -q fisher; and test -f "$__fish_config_dir/fish_plugins"
        fisher update
    else if type -q fisher
        echo "[upd] fish_plugins not found, installing default plugins"
        fisher install jorgebucaran/fisher icezyclon/zoxide.fish jorgebucaran/autopair.fish patrickf1/fzf.fish
    else
        echo "[upd] fisher not found, skipping fisher update"
    end
end
