function ports -d "List listening TCP ports"
    if test (count $argv) -gt 1; or begin
            test (count $argv) -eq 1
            and not string match -qr '^[0-9]+$' -- $argv[1]
        end
        echo "Usage: ports [port]"
        return 1
    end

    if test (count $argv) -eq 1; and test "$argv[1]" -lt 1 -o "$argv[1]" -gt 65535
        echo "ports: port must be between 1 and 65535" >&2
        return 1
    end

    if not command -q lsof
        echo "ports: lsof is required" >&2
        return 1
    end

    if test (count $argv) -eq 0
        command lsof -nP -iTCP -sTCP:LISTEN
    else
        command lsof -nP -iTCP -sTCP:LISTEN | command grep -E "(:|\*)$argv[1]( |\$)"
    end
end
