# Use zmv, which is amazing
autoload -U zmv

# Set VIM
set -o vi

eval "$(zoxide init zsh)"

#source $HOME/.rvm/scripts/rvm
source "$HOME/.cargo/env"
eval "$(pyenv init - --no-rehash)"
eval "$(pyenv virtualenv-init -)"
