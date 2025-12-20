function upup -d "updates different tools"
    brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor
    pnpm self-update
    /opt/homebrew/bin/fish -C "fisher update"
    nvim --headless "+Lazy! sync" +qa
end
