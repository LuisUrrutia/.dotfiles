status is-interactive || exit

abbr -a -- find 'fd'
abbr -a -- top 'btop'

# brew
abbr -a -- brewup 'brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor'

# ps
abbr -a -- psa 'ps aux'
abbr -a -- psg 'ps aux | grep'

# du and df
abbr -a -- du 'du -h -d 2'
abbr -a -- df 'df -h'

# git
abbr -a -- gs 'git status'
abbr -a -- gd 'git diff'
abbr -a -- gdc 'git diff --cached -w'
abbr -a -- gds 'git diff --staged -w'
abbr -a -- gsta 'git stash'
abbr -a -- gsw 'git switch'
abbr -a -- gsh 'git show'
abbr -a -- gshw 'git show'
abbr -a -- gc 'git commit'
abbr -a -- gcm 'git commit -m'
abbr -a -- gco 'git checkout'
abbr -a -- gnb 'git switch -c'
abbr -a -- ga 'git add'
abbr -a -- gm 'git merge'
abbr -a -- gms 'git merge --squash'
abbr -a -- grv 'git remote -v'
abbr -a -- grb 'git rebase'
abbr -a -- grba 'git rebase --abort'
abbr -a -- grbc 'git rebase --continue'
abbr -a -- grbi 'git rebase --interactive'
abbr -a -- gl 'git log --graph --date=short'
abbr -a -- gf 'git fetch'
abbr -a -- gfp 'git fetch --prune'
abbr -a -- gfa 'git fetch --all'
abbr -a -- gfap 'git fetch --all --prune'
abbr -a -- gb 'git branch -v'
abbr -a -- gpl 'git pull'

function gpll
    echo "git pull origin $(git rev-parse --abbrev-ref HEAD)"
end
abbr -a gpll --position command --function gpll
abbr -a -- gplr 'git pull --rebase'
abbr -a -- gps 'git push'

function gpsh
    echo "git push -u origin $(git rev-parse --abbrev-ref HEAD)"
end
abbr -a gpsh --position command --function gpsh
abbr -a -- gpshf 'git push --force-with-lease --force-if-includes'
abbr -a -- grs 'git reset'
abbr -a -- grsh 'git reset --hard'
abbr -a -- gcln 'git clean'
abbr -a -- gclndf 'git clean -df'
abbr -a -- gclndfx 'git clean -dfx'
abbr -a -- gt 'git tag'
abbr -a -- gbg 'git bisect good'
abbr -a -- gbb 'git bisect bad'
abbr -a -- gst 'git staash'
abbr -a -- gbn 'git branch-name'
abbr -a -- grbs 'git recent-branches'

abbr -a -- gwl 'git worktree list'
abbr -a -- gwrm 'git worktree remove'
abbr -a -- gwp 'git worktree prune'
abbr -a -- gwa 'git worktree add'
abbr -a -- gwmv 'git worktree move'
abbr -a -- gwlock 'git worktree lock'
abbr -a -- gwunlock 'git worktree unlock'

abbr -a -- amend 'git commit --amend'
abbr -a -- unstage 'git reset HEAD'
abbr -a -- uncommit 'git reset --soft HEAD^'

# kill
abbr -a -- ka9 'killall -9'
abbr -a -- k9 'kill -9'

# docker
abbr -a -- dstop 'docker stop'
abbr -a -- dps 'docker ps'
abbr -a -- dpss 'docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"'
abbr -a -- dpsa 'docker ps -a'
abbr -a -- dexec 'docker exec -it'
abbr -a -- dc 'docker compose'
abbr -a -- dcu 'docker compose up'
abbr -a -- dcd 'docker compose down'
abbr -a -- dcs 'docker compose stop'

# clean
abbr -a -- clean-js 'fd -I -t d "^(node_modules|build|dist)$" -x rm -rf {}'

# ip
abbr -a -- localip 'ipconfig getifaddr en0'

# fisher
abbr -a -- fi 'fisher install'
abbr -a -- fl 'fisher list'
abbr -a -- fu 'fisher update'
abbr -a -- fr 'fisher remove'

# iCloud
abbr -a -- icloud 'cd "$HOME/Library/Mobile Documents/com~apple~CloudDocs"'
abbr -a -- obsidian 'cd "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"'