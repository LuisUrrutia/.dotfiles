#
# Executes commands at the start of an interactive session.
#

# region modules
function zcompile-many() {
  local f
  for f; do zcompile -R -- "$f".zwc "$f"; done
}

# Clone and compile to wordcode missing plugins.
if [[ ! -e ~/.zmodules/zsh-syntax-highlighting ]]; then
  mkdir ~/.zmodules
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zmodules/zsh-syntax-highlighting
  zcompile-many ~/.zmodules/zsh-syntax-highlighting/{zsh-syntax-highlighting.zsh,highlighters/*/*.zsh}
fi
if [[ ! -e ~/.zmodules/zsh-autosuggestions ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.zmodules/zsh-autosuggestions
  zcompile-many ~/.zmodules/zsh-autosuggestions/{zsh-autosuggestions.zsh,src/**/*.zsh}
fi
if [[ ! -e ~/.zmodules/zsh-history-substring-search ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search ~/.zmodules/zsh-history-substring-search
  zcompile-many ~/.zmodules/zsh-history-substring-search/{zsh-history-substring-search.zsh,src/**/*.zsh}
fi
if [[ ! -e ~/.zmodules/zsh-completions ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions.git ~/.zmodules/zsh-completions
fi
if [[ ! -e ~/.zmodules/powerlevel10k ]]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.zmodules/powerlevel10k
  make -C ~/.zmodules/powerlevel10k pkg
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

autoload -Uz compinit && compinit
[[ ~/.zcompdump.zwc -nt ~/.zcompdump ]] || zcompile-many ~/.zcompdump
unfunction zcompile-many

source ~/.zmodules/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zmodules/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zmodules/zsh-history-substring-search/zsh-history-substring-search.zsh
source ~/.zmodules/powerlevel10k/powerlevel10k.zsh-theme
source ~/.p10k.zsh

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
# endregion

# Load custom aliases
source ~/.zsh_aliases

# Load custom functions
source ~/.zsh_functions

# GNU sed
PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"

# rvm
export PATH="$PATH:$HOME/.rvm/bin"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Google cloud sdk
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

# mise
eval "$(mise activate zsh)"

# Enable Zoxide
eval "$(zoxide init zsh)"

# Set VIM
set -o vi

random_phrase
