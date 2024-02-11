# `tre` is a shorthand for `tree` with hidden files and color enabled, ignoring
# the `.git` directory, listing directories first. The output gets piped into
# `less` with options to preserve color and line numbers, unless the output is
# small enough for one screen.
function tre() {
	tree -aC -I '.git|node_modules|bower_components' --dirsfirst "$@" | less -FRNX;
}

function nuke() {
  kill $(ps aux | grep '[A]dobe' | awk '{print $2}')
  kill $(ps aux | grep '[F]orti[C]lient' | awk '{print $2}')
  kill $(ps aux | grep '[L]ogitech' | awk '{print $2}')
  kill $(ps aux | grep 'toolbox-helper' | awk '{print $2}')
}

envup() {
  local file=$([ -z "$1" ] && echo ".env" || echo ".env.$1")

  if [ -f $file ]; then
    set -a
    source $file
    set +a
  else
    echo "No $file file found" 1>&2
    return 1
  fi
}

awss() {
  export AWS_PROFILE=$1
  echo "Using AWS_PROFILE=$1"
}

random_phrase() {
  # Define an array of phrases
  local short_phrases=(
    "Change is the only constant" \
    "Stay hungry, stay foolish" \
    "Failure teaches success" \
    "Think big, start small" \
    "Practice makes perfect" \
    "Keep your commitments" \
    "Knowledge is power" \
    "Grow 1% every day" 
  )

  local long_phrases=(
    "Be productive early. Do not fuck around all day" \
    "Be fucking practical. Success is not a theory" \
    "Stop bullshitting. It is fucking embarrassing" \
    "Care about the process, not just the outcome" \
    "Acquire new knowledge and always ask why" \
    "Hope for the best, prepare for the worst" \
    "Keep it simple, stupid (KISS principle)" \
    "Do the fucking work. Do not be lazy" \
    "Stop fucking waiting. It is time" \
    "Actions speak louder than words" \
    "Fail by action, not inaction" 
  )

  local cols=$(tput cols)

  local phrases_to_use=()
  if (( cols < 90 )); then
    phrases_to_use=("${short_phrases[@]}")
  else
    phrases_to_use=("${short_phrases[@]}" "${long_phrases[@]}")
  fi

  random_phrase=$(printf "%s\n" "${phrases_to_use[@]}" | shuf -n 1)

  figlet -w $cols "$random_phrase" | lolcrab -g cool
}
