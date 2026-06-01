function machash -d "Print this Mac's hardware hash"
    set -l uuid (/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F '"' '/IOPlatformUUID/ { print $4; exit }')

    if test -z "$uuid"
        echo "machash: unable to read IOPlatformUUID" >&2
        return 1
    end

    printf '%s' "$uuid" | /usr/bin/shasum -a 256 | /usr/bin/cut -c1-12
end
