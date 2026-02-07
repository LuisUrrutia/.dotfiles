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
        fnm install --lts
        set -l lts_line (fnm list | string match -r '.*lts-latest.*')
        if test -n "$lts_line"
            set -l lts_version (string match -r 'v[0-9.]+' -- "$lts_line")
            if test -n "$lts_version"
                fnm default "$lts_version"
            end
        end
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
    else
        echo "[upup] nvim not found, skipping"
    end

    if command -q mo
        mo clean
    else
        echo "[upup] mo not found, skipping"
    end

    # Fish update should be at the end of the function.
    if command -q fish
        command fish -C "fisher update"
    else
        echo "[upup] fish not found, skipping fisher update"
    end
end
