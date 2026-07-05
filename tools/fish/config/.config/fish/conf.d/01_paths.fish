# Add local bins and tool-specific bins to PATH.
fish_add_path --prepend --path --move \
    "$HOME/.local/bin" \
    "$HOMEBREW_PREFIX/bin" \
    "$HOMEBREW_PREFIX/sbin" \
    "$HOMEBREW_PREFIX/opt/rustup/bin"

fish_add_path --append --path --move \
    "$HOME/Library/pnpm" \
    "$HOME/Library/pnpm/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.foundry/bin" \
    "$HOME/.opencode/bin"

set -gx RIPGREP_CONFIG_PATH "$HOME/.config/ripgrep/ripgreprc"
