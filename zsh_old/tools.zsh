# Use zmv, which is amazing
autoload -U zmv

# Set VIM
set -o vi

eval "$(zoxide init zsh)"

#source $HOME/.rvm/scripts/rvm
source "$HOME/.cargo/env"
eval "$(pyenv init - --no-rehash)"
eval "$(pyenv virtualenv-init -)"

function change-commit-date() {
  export GIT_AUTHOR_DATE=`gdate -d"$1" --rfc-email`
  export GIT_COMMITTER_DATE=$GIT_AUTHOR_DATE

  echo "Changing date to ${GIT_AUTHOR_DATE}"
  git commit --amend --no-edit --date "${GIT_AUTHOR_DATE}"
}

function unpinning() {
  frida -U -l "$HOME/.lsuf/frida-script.js" -f $1
}


# WIP: toogle monitors for second computer
displayPort1=15
hdmi1=17
hdmi2=18

left_monitor="ddcctl -d 3"
middle_monitor="ddcctl -d 1"
right_monitor="ddcctl -d 2"

function get_current_source() {
  local monitor=$1
  local result=$(eval "$monitor -i '?' | awk -F'[ ,]+' '/VCP control #/ {print \$(NF-2)}'")
  echo "$result"
}

function toggle_left_monitor() {
  local current=$(get_current_source $left_monitor)
  if [ "$current" -eq "$hdmi2" ] || [ "$current" -eq "$hdmi1" ]; then
    eval "$left_monitor -i $displayPort1"
  else
    eval "$left_monitor -i $hdmi2"
  fi
}

function toggle_center_monitor() {
  local current=$(get_current_source $middle_monitor)
  if [ "$current" -eq "$hdmi2" ] || [ "$current" -eq "$hdmi1" ]; then
    eval "$middle_monitor -i $displayPort1"
  else
    eval "$middle_monitor -i $hdmi1"
  fi
}

function tailwatch () {
  aws logs tail "$1" --follow --format short
}
