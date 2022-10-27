# `tre` is a shorthand for `tree` with hidden files and color enabled, ignoring
# the `.git` directory, listing directories first. The output gets piped into
# `less` with options to preserve color and line numbers, unless the output is
# small enough for one screen.
function tre() {
	tree -aC -I '.git|node_modules|bower_components' --dirsfirst "$@" | less -FRNX;
}

function killshit() {
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
