zmodload zsh/stat

BREW_PREFIX=${BREW_PREFIX:-$(brew --prefix)}
ZCOMPDUMP_FILE=${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump
CURRENT_TIME=$EPOCHSECONDS
UPDATE_INTERVAL=$((24 * 60 * 60))

# region: History
HISTFILE=${XDG_CACHE_HOME:-$HOME/.cache}/.zsh_history
HISTSIZE=999999999
SAVEHIST=$HISTSIZE
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
setopt hist_ignore_dups # Ignore duplicates in history
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
  "https://github.com/romkatv/powerlevel10k.git powerlevel10k"
)
for plugin in "${plugins[@]}"; do
  repo=${plugin%% *}
  dir=${plugin##* }
  if [[ ! -d "$ZMODULES/$dir" ]]; then
    git clone --depth=1 "$repo" "$ZMODULES/$dir"
    if [[ "$dir" == "powerlevel10k" ]]; then
      make -C "$ZMODULES/powerlevel10k" pkg
    fi
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
zcompile_if_needed ~/.p10k.zsh

autoload -Uz compinit
if [[ -f $ZCOMPDUMP_FILE ]]; then
  ZCOMPDUMP_MTIME=$(gstat -c %Y "$ZCOMPDUMP_FILE")
else
  ZCOMPDUMP_MTIME=0
fi

if (( CURRENT_TIME - ZCOMPDUMP_MTIME > UPDATE_INTERVAL )); then
  compinit -i -d $ZCOMPDUMP_FILE
  zcompile_if_needed $ZCOMPDUMP_FILE
else
  compinit -i -d $ZCOMPDUMP_FILE -D
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# fzf
if [ ! -f ~/.fzf.zsh ]; then
	$BREW_PREFIX/opt/fzf/install --all --no-bash --no-fish --no-update-rc --key-bindings --completion
fi
source ~/.fzf.zsh
(source ~/.zmodules/fzf-tab/fzf-tab.plugin.zsh) &!

# Load other plugins
source ~/.zmodules/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zmodules/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zmodules/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.zmodules/powerlevel10k/powerlevel10k.zsh-theme
source ~/.p10k.zsh
[ -f "$BREW_PREFIX/share/forgit/forgit.plugin.zsh" ] && source "$BREW_PREFIX/share/forgit/forgit.plugin.zsh"

source ~/.zsh_aliases
source ~/.zsh_functions 
source ~/.zsh_bindkeys 
{
  source ~/.zsh_fzf # deferred load
} &!

if [[ -f ~/.zsh_work ]]; then
  {
    source ~/.zsh_work
  } &!
fi

unfunction zcompile-many zcompile_if_needed

export BUN_INSTALL="$HOME/.bun"
# Use GNU sed and grep add rvm and bun to path
PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:/opt/homebrew/opt/grep/libexec/gnubin:$BUN_INSTALL/bin:$PATH:$HOME/.rvm/bin"
typeset -U path # remove duplicates

# Google cloud sdk
source "$BREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
source "$BREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"

# mise
eval "$(mise activate zsh)"

# Enable Zoxide
eval "$(zoxide init zsh)"

# Set VIM
set -o vi

if [[ "$TERM_PROGRAM" != "vscode" && -z "$TMUX" ]]; then
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
	random_phrase
fi
