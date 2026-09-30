function killport -d "Kill process listening on a TCP port"
    argparse --max-args=1 -n killport n/dry-run y/yes h/help -- $argv
    or return

    if set -q _flag_help
        echo "Usage: killport [options] [port]"
        echo "  -n, --dry-run    Show listening processes and the TERM that would be sent"
        echo "  -y, --yes        Send TERM without prompting"
        echo "  -h, --help       Show this help message"
        echo "  no port          Select a listening TCP port with fzf"
        return 0
    end

    set -l port $argv[1]

    if test -z "$port"
        if not type -q fzf
            echo "killport: fzf is required for interactive port selection" >&2
            return 1
        end

        set -l selection (__fish_listening_ports | command awk -F '\t' '{ printf "%s\t%-8s %-24s %8s  %s\n", $1, $1, $2, $3, $4 }' | fzf --with-shell 'fish -c' --prompt='TCP port> ' --header='PORT     COMMAND                       PID  ADDRESS' --delimiter='\t' --with-nth=2.. --preview='set -l pids (lsof -nP -iTCP:{1} -sTCP:LISTEN -t 2>/dev/null | sort -u); if test (count $pids) -gt 0; ps -p (string join , $pids) -o pid,ppid,comm,args; else; echo "No process is listening on TCP port {1}"; end')

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

    if set -q _flag_dry_run
        echo "Dry run: would send TERM to PID(s) "(string join ' ' $pids)" listening on TCP port $port"
        return 0
    end

    if not set -q _flag_yes
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
