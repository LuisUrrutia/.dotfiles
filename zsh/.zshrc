function zcompile-many() {
  local f
  for f; do zcompile -R -- "$f".zwc "$f"; done
}

# region: Plugin Management
ZMODULES="$HOME/.zmodules"
function clone_and_compile() {
  local repo=$1
  local dir=$2
  local files=$3

  if [[ ! -e $dir ]]; then
    git clone --depth=1 $repo $dir
    zcompile-many $files
  fi
}

clone_and_compile https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZMODULES/zsh-syntax-highlighting" \
  "$ZMODULES/zsh-syntax-highlighting/{zsh-syntax-highlighting.zsh,highlighters/*/*.zsh}"
clone_and_compile https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZMODULES/zsh-autosuggestions" \
  "$ZMODULES/zsh-autosuggestions/{zsh-autosuggestions.zsh,src/**/*.zsh}"
clone_and_compile https://github.com/zsh-users/zsh-history-substring-search \
  "$ZMODULES/zsh-history-substring-search" \
  "$ZMODULES/zsh-history-substring-search/{zsh-history-substring-search.zsh,**/*.zsh}"
clone_and_compile https://github.com/Aloxaf/fzf-tab \
  "$ZMODULES/fzf-tab" \
  "$ZMODULES/fzf-tab/{fzf-tab.zsh}"

if [[ ! -e "$ZMODULES/zsh-completions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions.git "$ZMODULES/zsh-completions"
fi

if [[ ! -e "$ZMODULES/powerlevel10k" ]]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZMODULES/powerlevel10k"
  make -C "$ZMODULES/powerlevel10k" pkg
fi

if [[ ! -e ~/.tmux/plugins/tpm ]]; then
  mkdir -p ~/.tmux/plugins
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# tmux plugin manager
if [[ ! -e "$HOME/.tmux/plugins/tpm" ]]; then
  mkdir -p "$HOME/.tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
# endregion

eval "$(brew shellenv)"

# Completion paths
fpath=(~/.zmodules/zsh-completions/src $(brew --prefix)/share/zsh/site-functions $fpath)
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

autoload -Uz compinit
compinit -D

[[ ~/.zcompdump.zwc -nt ~/.zcompdump ]] || zcompile-many ~/.zcompdump
[[ ~/.p10k.zsh.zwc  -nt ~/.p10k.zsh  ]] || zcompile-many ~/.p10k.zsh
unfunction zcompile-many

# region: History
HISTFILE=$HOME/.zsh_history
HISTSIZE=999999999
SAVEHIST=$HISTSIZE
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
setopt hist_ignore_dups # Ignore duplicates in history
# endregion

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# fzf
if [ ! -f ~/.fzf.zsh ]; then
  $(brew --prefix)/opt/fzf/install --all --no-bash --no-fish --no-update-rc --key-bindings --completion
fi
source ~/.fzf.zsh
source ~/.zmodules/fzf-tab/fzf-tab.plugin.zsh

# Load other plugins
source ~/.zmodules/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zmodules/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zmodules/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.zmodules/powerlevel10k/powerlevel10k.zsh-theme
source ~/.p10k.zsh
[ -f "$(brew --prefix)/share/forgit/forgit.plugin.zsh" ] && source "$(brew --prefix)/share/forgit/forgit.plugin.zsh"

source ~/.zsh_aliases # Aliases
source ~/.zsh_functions # Custon functions
source ~/.zsh_bindkeys # Custom bindkeys
source ~/.zsh_fzf

if [[ -f ~/.zsh_work ]]; then
  source ~/.zsh_work
fi

# region: Paths
# GNU sed
PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
# GNU grep
PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
# rvm
export PATH="$PATH:$HOME/.rvm/bin"
# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# endregion

# Google cloud sdk
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

# mise
eval "$(mise activate zsh)"

# Enable Zoxide
eval "$(zoxide init zsh)"

# Set VIM
set -o vi

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ "$TERM_PROGRAM" != "vscode" && -z "$TMUX" ]]; then
  random_phrase
fi

PATH=~/.console-ninja/.bin:$PATH