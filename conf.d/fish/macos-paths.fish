set -l prefix /opt/homebrew
set -gx DOTFILES_NATIVE_PREFIX $prefix
fish_add_path --append --path "$prefix/bin" "$prefix/sbin"
set -q MANPATH; or set -gx MANPATH ''
contains -- "$prefix/share/man" $MANPATH; or set -gx MANPATH "$prefix/share/man" $MANPATH
set -q INFOPATH; or set -gx INFOPATH ''
contains -- "$prefix/share/info" $INFOPATH; or set -gx INFOPATH "$prefix/share/info" $INFOPATH
