function ll --wraps eza -d "List every entry with details"
    if command -q eza
        eza --icons=auto --color=auto --group-directories-first --octal-permissions --git -alh --classify=auto $argv
    else
        command ls -lahF $argv
    end
end
