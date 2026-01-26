function upup -d "updates different tools"
    brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor
    fnm install --lts
    fnm default --lts
    corepack enable
    corepack prepare pnpm@latest --activate
    pnpm -g update
    nvim --headless "+Lazy! sync" +qa

    # Fish update should be at the end of the function
    /opt/homebrew/bin/fish -C "fisher update"
end
