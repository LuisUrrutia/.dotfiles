# Add local bins and gnu-sed/grep to path
fish_add_path --prepend --path --move "$HOME/.local/bin" "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" "$HOMEBREW_PREFIX/opt/rustup/bin"
fish_add_path --append --path --move "$HOME/Library/pnpm"  "$HOME/.rvm/bin" "$HOME/.foundry/bin" "$HOMEBREW_PREFIX/opt/openjdk/bin" "$HOME/.opencode/bin"
