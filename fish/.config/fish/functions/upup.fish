function upup -d "updates different tools"
    brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor
    pnpm self-update
    nvim --headless "+Lazy! sync" +qa

    # Fish update should be at the end of the function
    /opt/homebrew/bin/fish -C "fisher update"
end
