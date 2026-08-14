function rgi -d "Run ripgrep with the interactive user config"
    set -lx RIPGREP_CONFIG_PATH "$HOME/.config/ripgrep/ripgreprc"
    command rg $argv
end
