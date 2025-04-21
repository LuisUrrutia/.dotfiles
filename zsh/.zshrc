zmodload zsh/stat
zmodload zsh/datetime

BREW_PREFIX=${BREW_PREFIX:-$(brew --prefix)}
ZCOMPDUMP_FILE=${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump
skip_global_compinit=1

setopt NO_LIST_BEEP

# region: History
HISTFILE=${XDG_CACHE_HOME:-$HOME/.cache}/.zsh_history
HISTSIZE=1000000
SAVEHIST=$HISTSIZE

setopt HIST_IGNORE_DUPS # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS # Delete old recorded entry if new entry is a duplicate.
setopt SHARE_HISTORY # Share history between all sessions.
setopt HIST_FIND_NO_DUPS # Do not display a line previously found.
setopt HIST_SAVE_NO_DUPS # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS # Remove superfluous blanks before recording entry.
# endregion

function zcompile_if_needed() {
  local src="$1"
  local dest="$src.zwc"

  if [[ ! -s "$dest" || "$src" -nt "$dest" ]]; then
    zcompile -R -- "$dest" "$src"
  fi
}

function zcompile-many() {
  local pattern files
  for pattern in "$@"; do
    files=(${~pattern}(N))
    for f in "${files[@]}"; do
      zcompile_if_needed "$f"
    done
  done
}

# region: Plugin Management
ZMODULES="$HOME/.zmodules"
plugins=(
  "https://github.com/zsh-users/zsh-syntax-highlighting.git zsh-syntax-highlighting"
  "https://github.com/zsh-users/zsh-autosuggestions.git zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-history-substring-search zsh-history-substring-search"
  "https://github.com/Aloxaf/fzf-tab fzf-tab"
  "https://github.com/zsh-users/zsh-completions.git zsh-completions"
)
for plugin in "${plugins[@]}"; do
  repo=${plugin%% *}
  dir=${plugin##* }
  if [[ ! -d "$ZMODULES/$dir" ]]; then
    git clone --depth=1 "$repo" "$ZMODULES/$dir"
  fi
  zcompile-many ${(f)~ZMODULES}/${dir}/**/*.zsh(N)
done

if [[ ! -e "$HOME/.tmux/plugins/tpm" ]]; then
  mkdir -p "$HOME/.tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Completion paths
fpath=(~/.zmodules/zsh-completions/src $BREW_PREFIX/share/zsh/site-functions $fpath)

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

zcompile_if_needed $ZCOMPDUMP_FILE

autoload -Uz compinit

# Only regenerate the completion dump once a day
# -C flag skips the entire compinit security check, making it much faster
if [[ -n $ZCOMPDUMP_FILE(#qN.mh+24) ]]; then
  # If older than 24 hours, regenerate
  compinit -i -d $ZCOMPDUMP_FILE
  # Compile it for faster loading
  zcompile_if_needed $ZCOMPDUMP_FILE
else
  # Fast load from cache using -C flag to skip checks
  compinit -C -i -d $ZCOMPDUMP_FILE
fi

# fzf
if [ ! -f ~/.fzf.zsh ]; then
  $BREW_PREFIX/opt/fzf/install --all --no-bash --no-fish --no-update-rc --key-bindings --completion
fi
source ~/.fzf.zsh
source ~/.zmodules/fzf-tab/fzf-tab.plugin.zsh

# Load other plugins
source ~/.zmodules/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zmodules/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zmodules/zsh-history-substring-search/zsh-history-substring-search.zsh
[ -f "$BREW_PREFIX/share/forgit/forgit.plugin.zsh" ] && source "$BREW_PREFIX/share/forgit/forgit.plugin.zsh"

source ~/.zsh_aliases
source ~/.zsh_functions 
source ~/.zsh_bindkeys 
source ~/.zsh_fzf
[ -f ~/.zsh_work ] && source ~/.zsh_work

unfunction zcompile-many zcompile_if_needed

export BUN_INSTALL="$HOME/.bun"
# Use GNU sed and grep add rvm and bun to path
PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:/opt/homebrew/opt/grep/libexec/gnubin:$BUN_INSTALL/bin:$PATH:$HOME/.rvm/bin"
typeset -U path # remove duplicates

# Google cloud sdk
source "$BREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
source "$BREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"

# Set VIM
set -o vi

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
source <(stellar completion --shell zsh)

# Display random phrase if not in VSCode and not in tmux
if [[ "$TERM_PROGRAM" != "vscode" && -z "$TMUX" ]]; then
  random_phrase
fi
