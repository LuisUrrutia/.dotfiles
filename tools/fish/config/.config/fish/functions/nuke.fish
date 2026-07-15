function nuke -d "Kill unwanted background processes"
    set -l process_names \
        FortiClient \
        FortiClientAgent \
        FortiTray \
        Logitech \
        lghub \
        lghub_agent \
        lghub_system_tray \
        toolbox-helper

    set -l total_killed 0

    for arg in $argv
        switch $arg
            case -h --help
                echo "Usage: nuke [--help]"
                echo "  -h, --help       Show this help message"
                return 0
            case '*'
                echo "nuke: unknown option: $arg" >&2
                return 1
        end
    end

    for process_name in $process_names
        set -l pids (pgrep -x "$process_name" 2>/dev/null)

        if test (count $pids) -gt 0
            set -l killed_count (count $pids)
            echo "Killing $killed_count process(es) named '$process_name'..."

            for pid in $pids
                if kill $pid 2>/dev/null
                    echo "  Killed PID $pid"
                    set total_killed (math $total_killed + 1)
                else
                    echo "  Failed to kill PID $pid (may already be dead)"
                end
            end
        end
    end

    pkill -9 -f "Google Chrome"

    if test $total_killed -gt 0
        echo ""
        echo "Successfully killed $total_killed process(es)"
    else
        echo "No matching processes found to kill"
    end
end
