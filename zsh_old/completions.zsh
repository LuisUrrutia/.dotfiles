_awss() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments '1: :->csi'

    case $state in
    csi)
      _arguments "1: :($(aws configure list-profiles))"
    ;;
    esac
}

compdef _awss awss
