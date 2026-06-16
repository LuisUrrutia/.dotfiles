function backup-configs -d "Back up Thaw and Raycast configs"
    if test (count $argv) -ne 0
        printf '%s\n' 'Usage: backup-configs' >&2
        return 1
    end

    for backup_command in thaw-config raycast-config
        if not command -q $backup_command
            printf 'backup-configs: missing command: %s\n' "$backup_command" >&2
            return 127
        end
    end

    set -l state_dir (command mktemp -d)
    or return 1

    set -l thaw_status_file "$state_dir/thaw.status"
    set -l raycast_status_file "$state_dir/raycast.status"
    set -l pid_list

    begin
        printf '%s\n' '[thaw] backup starting'
        command thaw-config backup
        set -l thaw_status $status
        printf '%s\n' $thaw_status >"$thaw_status_file"

        if test $thaw_status -eq 0
            printf '%s\n' '[thaw] backup complete'
        else
            printf '[thaw] backup failed with status %s\n' "$thaw_status" >&2
        end
    end &
    set --append pid_list (jobs --last --pid)

    begin
        printf '%s\n' '[raycast] backup starting'
        command raycast-config backup
        set -l raycast_status $status
        printf '%s\n' $raycast_status >"$raycast_status_file"

        if test $raycast_status -eq 0
            printf '%s\n' '[raycast] backup complete'
        else
            printf '[raycast] backup failed with status %s\n' "$raycast_status" >&2
        end
    end &
    set --append pid_list (jobs --last --pid)

    wait $pid_list 2>/dev/null

    set -l failed 0

    for backup_name in thaw raycast
        set -l status_file "$state_dir/$backup_name.status"

        if not test -f "$status_file"
            printf '[%s] backup status was not recorded\n' "$backup_name" >&2
            set failed 1
            continue
        end

        set -l backup_status (string trim (command cat "$status_file"))

        if test "$backup_status" != 0
            set failed 1
        end
    end

    command rm -rf "$state_dir"

    return $failed
end
