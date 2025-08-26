function nuke -d "Kill unwanted background processes (Adobe, FortiClient, Logitech, toolbox-helper)"
    # Define process patterns to kill
    set -l process_patterns \
        "Adobe" \
        "FortiClient" \
        "Logitech" \
        "toolbox-helper"
    
    set -l total_killed 0
    set -l dry_run false
    
    # Parse arguments
    for arg in $argv
        switch $arg
            case -n --dry-run
                set dry_run true
            case -h --help
                echo "Usage: nuke [options]"
                echo "  -n, --dry-run    Show processes that would be killed without actually killing them"
                echo "  -h, --help       Show this help message"
                echo ""
                echo "Kills processes matching: Adobe, FortiClient, Logitech, toolbox-helper"
                return 0
        end
    end
    
    if test "$dry_run" = "true"
        echo "DRY RUN - Processes that would be killed:"
        echo "=========================================="
    end
    
    # Kill processes for each pattern
    for pattern in $process_patterns
        # Use pgrep for more reliable process matching
        set -l pids (pgrep -f "$pattern" 2>/dev/null)
        
        if test (count $pids) -gt 0
            if test "$dry_run" = "true"
                echo "Pattern '$pattern':"
                ps -p $pids -o pid,ppid,comm,args 2>/dev/null | head -20
                echo ""
            else
                set killed_count (count $pids)
                echo "Killing $killed_count process(es) matching '$pattern'..."
                
                # Kill processes gracefully first (TERM), then forcefully (KILL) if needed
                for pid in $pids
                    if kill $pid 2>/dev/null
                        echo "  Killed PID $pid"
                        set total_killed (math $total_killed + 1)
                    else
                        echo "  Failed to kill PID $pid (may already be dead)"
                    end
                end
            end
        else
            if test "$dry_run" = "true"
                echo "Pattern '$pattern': No processes found"
            end
        end
    end
    
    if test "$dry_run" = "false"
        if test $total_killed -gt 0
            echo ""
            echo "Successfully killed $total_killed process(es)"
        else
            echo "No matching processes found to kill"
        end
    end
end
