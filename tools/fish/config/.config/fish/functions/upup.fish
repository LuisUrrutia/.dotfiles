function upup -d "updates different tools"
    if command -q brew
        brew update
        and brew upgrade
        and brew autoremove
        and brew cleanup --prune=all
        and brew doctor
    else
        echo "[upup] brew not found, skipping"
    end

    if command -q fnm
        fnm install --lts --use --corepack-enabled
        fnm default lts-latest
    else
        echo "[upup] fnm not found, skipping"
    end

    if command -q corepack
        corepack enable
        corepack prepare pnpm@latest --activate
    else
        echo "[upup] corepack not found, skipping"
    end

    if command -q pnpm
        pnpm -g update
    else
        echo "[upup] pnpm not found, skipping"
    end

    if command -q nvim
        nvim --headless "+Lazy! sync" +qa
        nvim --headless "+lua require('config.treesitter').install()" +qa
    else
        echo "[upup] nvim not found, skipping"
    end

    if command -q mo
        mo clean
    else
        echo "[upup] mo not found, skipping"
    end

    if test -d "$HOME/.cache/opencode"
        echo "[upup] removing OpenCode cache"
        rm -rf "$HOME/.cache/opencode"
    end

    # Fish plugin update should be at the end of the function.
    if command -q fish
        command fish -ic "fisher update"
    else
        echo "[upup] fish not found, skipping fisher update"
    end
end
