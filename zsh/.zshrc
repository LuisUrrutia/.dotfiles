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
source ~/.zmodules/zsh-completions/zsh-completions.plugin.zsh
source ~/.zmodules/powerlevel10k/powerlevel10k.zsh-theme
source ~/.p10k.zsh
# endregion

# Load custom aliases
source ~/.zshaliases

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

# >>> mamba initialize >>>
export MAMBA_EXE='/opt/homebrew/bin/micromamba';
export MAMBA_ROOT_PREFIX="$HOME/.micromamba";
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<


random_phrase
