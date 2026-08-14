# Add local bins and tool-specific bins to PATH.
fish_add_path --prepend --path --move \
    "$HOME/.local/bin" \
    "$HOMEBREW_PREFIX/bin" \
    "$HOMEBREW_PREFIX/sbin" \
    "$HOMEBREW_PREFIX/opt/rustup/bin"
