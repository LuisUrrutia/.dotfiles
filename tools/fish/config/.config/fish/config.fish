if status is-interactive
    starship init fish | source
    zoxide init fish | source

    set -gx FZF_DEFAULT_OPTS "\
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

    set fzf_diff_highlighter delta --paging=never --width=20
    set fzf_history_time_format %d-%m-%y
end

set -gx GPG_TTY $(tty)
set -gx LANG en_US.UTF-8
set -gx PAGER less
set -gx PNPM_HOME "$HOME/Library/pnpm"
