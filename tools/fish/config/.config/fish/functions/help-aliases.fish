function help-aliases -d "Show useful shell aliases and abbreviations"
    printf '%s\n' "Useful shell shortcuts"
    printf '%s\n' "======================"

    printf '\n%s\n' Navigation
    printf '  %-12s %s\n' dl "cd ~/Downloads"
    printf '  %-12s %s\n' desk "cd ~/Desktop"
    printf '  %-12s %s\n' f "open Finder here"
    printf '  %-12s %s\n' icloud "cd iCloud Drive"
    printf '  %-12s %s\n' obsidian "cd Obsidian iCloud vaults"

    printf '\n%s\n' Git
    printf '  %-12s %s\n' gd "git diff"
    printf '  %-12s %s\n' gc/gcm "git commit / git commit -m"
    printf '  %-12s %s\n' gsta/gstp "git stash / git stash pop"
    printf '  %-12s %s\n' gl/glog "git log graph views"
    printf '  %-12s %s\n' glogf "pick and show a commit with fzf"
    printf '  %-12s %s\n' prs "show current GitHub PR status"
    printf '  %-12s %s\n' wtpr "open a PR in a WorkTrunk worktree"
    printf '  %-12s %s\n' gps "git push"
    printf '  %-12s %s\n' gpll "pull current branch"
    printf '  %-12s %s\n' "git dm" "delete merged local branches"
    printf '  %-12s %s\n' "git top" "show top commit authors"

    printf '\n%s\n' "Docker and infra"
    printf '  %-12s %s\n' d docker
    printf '  %-12s %s\n' dc "docker compose"
    printf '  %-12s %s\n' dps/dpsa "docker ps / docker ps -a"
    printf '  %-12s %s\n' dcu/dcd "docker compose up / down"
    printf '  %-12s %s\n' dprune "prune stopped Docker resources"
    printf '  %-12s %s\n' tf terraform

    printf '\n%s\n' Terminal
    printf '  %-12s %s\n' c opencode
    printf '  %-12s %s\n' cld claude
    printf '  %-12s %s\n' h history
    printf '  %-12s %s\n' j "jobs -l"
    printf '  %-12s %s\n' paths "print PATH entries"
    printf '  %-12s %s\n' chmodx "chmod +x"

    printf '\n%s\n' Disk
    printf '  %-12s %s\n' dus "summarize disk usage two levels deep"
    printf '  %-12s %s\n' dfu "show disk free space with duf"

    printf '\n%s\n' Images
    printf '  %-12s %s\n' img2jpg "convert to JPG; use --medium/--small for presets"
    printf '  %-12s %s\n' img2png "convert to optimized PNG; use --quantize for pngquant"
    printf '  %-12s %s\n' imgoptimize "resize and optimize images in the current tree"

    printf '\n%s\n' Network
    printf '  %-12s %s\n' localip "show en0 local IP"
    printf '  %-12s %s\n' myip/ip "show public IP"
    printf '  %-12s %s\n' ports "list listening ports"
    printf '  %-12s %s\n' fip "forward localhost ports over SSH; use --list to inspect"
    printf '  %-12s %s\n' killport "confirm before killing a port listener"
    printf '  %-12s %s\n' netcons "list network connections"
    printf '  %-12s %s\n' flushdns "flush macOS DNS cache"
    printf '  %-12s %s\n' tailscale "run Tailscale CLI"

    printf '\n%s\n' Utilities
    printf '  %-12s %s\n' cx "cd and list"
    printf '  %-12s %s\n' fdf fd
    printf '  %-12s %s\n' mkd "make directory and cd into it"
    printf '  %-12s %s\n' top btop
    printf '  %-12s %s\n' today "date YYYY/MM/DD"
    printf '  %-12s %s\n' timestamp "date YYYYMMDDHHMMSS"
    printf '  %-12s %s\n' epoch "Unix epoch timestamp"
    printf '  %-12s %s\n' upd "update tools (use --force to bypass daily/weekly gates)"
    printf '  %-12s %s\n' weather "curl wttr.in"
    printf '  %-12s %s\n' halp/cheat "show local command notes"
end
