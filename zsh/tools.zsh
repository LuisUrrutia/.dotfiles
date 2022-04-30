# Use zmv, which is amazing
autoload -U zmv

# Set VIM
set -o vi

eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
