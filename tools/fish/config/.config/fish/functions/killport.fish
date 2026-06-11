function killport -d "Kill process listening on a TCP port"
    set -l dry_run false
    set -l assume_yes false
    set -l port

    for arg in $argv
        switch $arg
            case -n --dry-run
                set dry_run true
            case -y --yes
                set assume_yes true
            case -h --help
                echo "Usage: killport [options] [port]"
                echo "  -n, --dry-run    Show listening processes and the TERM that would be sent"
                echo "  -y, --yes        Send TERM without prompting"
                echo "  -h, --help       Show this help message"
                echo "  no port          Select a listening TCP port with fzf"
                return 0
            case '-*'
                echo "killport: unknown option '$arg'" >&2
                return 1
            case '*'
                if test -n "$port"
                    echo "killport: expected exactly one port" >&2
                    return 1
                end
                set port $arg
        end
    end

    if test -z "$port"
        if not type -q fzf
            echo "killport: fzf is required for interactive port selection" >&2
            return 1
        end

        set -l selection (lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 { split($9, address, ":"); port = address[length(address)]; if (port ~ /^[0-9]+$/) printf "%s\t%-8s %-24s %8s  %s\n", port, port, $1, $2, $9 }' | sort -n -u | fzf --with-shell 'fish -c' --prompt='TCP port> ' --header='PORT     COMMAND                       PID  ADDRESS' --delimiter='\t' --with-nth=2.. --preview='set -l pids (lsof -nP -iTCP:{1} -sTCP:LISTEN -t 2>/dev/null | sort -u); if test (count $pids) -gt 0; ps -p (string join , $pids) -o pid,ppid,comm,args; else; echo "No process is listening on TCP port {1}"; end')

        if test -z "$selection"
            echo "Cancelled; no processes killed."
            return 1
        end

        set port (string split -m1 \t -- "$selection")[1]
    end

    if not string match -qr '^[0-9]+$' -- "$port"
        echo "killport: port must be numeric" >&2
        return 1
    end

    if test "$port" -lt 1 -o "$port" -gt 65535
        echo "killport: port must be between 1 and 65535" >&2
        return 1
    end

    set -l pids (lsof -nP -iTCP:$port -sTCP:LISTEN -t 2>/dev/null | sort -u)

    if test (count $pids) -eq 0
        echo "No process is listening on TCP port $port"
        return 0
    end

    set -l pid_list (string join , $pids)
    ps -p "$pid_list" -o pid,ppid,comm,args

    if test "$dry_run" = true
        echo "Dry run: would send TERM to PID(s) "(string join ' ' $pids)" listening on TCP port $port"
        return 0
    end

    if test "$assume_yes" != true
        set -l prompt "Send TERM to PID(s) "(string join ' ' $pids)" listening on TCP port $port? [y/N] "
        read -l -P "$prompt" confirm
        switch (string lower -- "$confirm")
            case y yes
            case '*'
                echo "Cancelled; no processes killed."
                return 1
        end
    end

    set -l failed false

    for pid in $pids
        if kill -TERM $pid 2>/dev/null
            echo "Sent TERM to PID $pid listening on TCP port $port"
        else
            echo "Failed to send TERM to PID $pid" >&2
            set failed true
        end
    end

    if test "$failed" = true
        return 1
    end
end
