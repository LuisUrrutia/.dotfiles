set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR "$HOMEBREW_PREFIX/Cellar"
set -gx HOMEBREW_REPOSITORY "$HOMEBREW_PREFIX/homebrew"
set -gx CPLUS_INCLUDE_PATH "$HOMEBREW_PREFIX/include"
set -gx HOMEBREW_NO_ANALYTICS 1

if not set -q MANPATH
    set MANPATH ''
end
set -gx MANPATH "$HOMEBREW_PREFIX/share/man" $MANPATH

if not set -q INFOPATH
    set INFOPATH ''
end
set -gx INFOPATH "$HOMEBREW_PREFIX/share/info" $INFOPATH

if test -d "$HOMEBREW_PREFIX/share/fish/completions"
    if not contains -- "$HOMEBREW_PREFIX/share/fish/completions" $fish_complete_path
        set -p fish_complete_path "$HOMEBREW_PREFIX/share/fish/completions"
    end
end

if test -d "$HOMEBREW_PREFIX/share/fish/vendor_completions.d"
    if not contains -- "$HOMEBREW_PREFIX/share/fish/vendor_completions.d" $fish_complete_path
        set -p fish_complete_path "$HOMEBREW_PREFIX/share/fish/vendor_completions.d"
    end
end
