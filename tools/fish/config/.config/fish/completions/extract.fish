complete --erase -c extract

function __fish_extract_archives
    for file in **/*.tar.bz2 **/*.tbz2 **/*.tar.gz **/*.tgz **/*.tar.xz **/*.tar **/*.bz2 **/*.rar **/*.gz **/*.zip **/*.Z **/*.7z
        test -f "$file"; or continue
        printf '%s\tarchive file\n' "$file"
    end | sort -u
end

complete -c extract -f -a '(__fish_extract_archives)'
