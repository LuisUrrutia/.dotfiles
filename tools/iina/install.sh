#!/usr/bin/env bash

source "${DOTFILES:-$HOME/.dotfiles}/tools/lib.sh"

require_app IINA

# Leave ambiguous TypeScript (.ts/.mts) and audio extensions with their existing apps.
set_default_app_for_extensions IINA com.colliderli.iina \
  mp4 m4v mov qt mkv avi webm mpeg mpg wmv flv ogv ogm m2ts vob 3gp 3g2 rmvb mxf
