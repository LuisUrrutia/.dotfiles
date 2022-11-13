# Use zmv, which is amazing
autoload -U zmv

# Set VIM
set -o vi

eval "$(jump shell)"

#source $HOME/.rvm/scripts/rvm
source "$HOME/.cargo/env"
eval "$(pyenv init - --no-rehash)"
eval "$(pyenv virtualenv-init -)"

export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

