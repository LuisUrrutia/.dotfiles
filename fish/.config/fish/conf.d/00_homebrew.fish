set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR $HOMEBREW_PREFIX/Cellar
set -gx HOMEBREW_REPOSITORY $HOMEBREW_PREFIX/homebrew
set -gx CPLUS_INCLUDE_PATH $HOMEBREW_PREFIX/include
set -Ux HOMEBREW_NO_ANALYTICS 1
! set -q MANPATH; and set MANPATH ''; set -gx MANPATH "$HOMEBREW_PREFIX/share/man" $MANPATH;
! set -q INFOPATH; and set INFOPATH ''; set -gx INFOPATH "$HOMEBREW_PREFIX/share/info" $INFOPATH;

if test -d "$HOMEBREW_PREFIX/share/fish/completions"
    set -p fish_complete_path $fish_complete_path $HOMEBREW_PREFIX/share/fish/completions
end

if test -d "$HOMEBREW_PREFIX/share/fish/vendor_completions.d"
    set -p fish_complete_path $fish_complete_path $HOMEBREW_PREFIX/share/fish/vendor_completions.d
end