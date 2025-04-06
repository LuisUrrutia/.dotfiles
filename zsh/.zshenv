#
# Defines environment variables.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

export PAGER='less'
export EDITOR='nvim';
export VISUAL='nvim'

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export GPG_TTY=$(tty);
export CPLUS_INCLUDE_PATH=/opt/homebrew/include

# Android platform tools
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_TOOLS="$ANDROID_HOME/platform-tools"

# Golang
export GOPATH="$HOME/go"

export PATH=$HOME/.cargo/bin:${PATH}:$GOPATH/bin:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
. "$HOME/.cargo/env"
