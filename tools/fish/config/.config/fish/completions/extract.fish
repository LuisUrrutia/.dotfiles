complete --erase -c extract
complete -c extract -k -x -a '(__fish_complete_suffix .tar.bz2 .tbz2 .tar.gz .tgz .tar.xz .tar.zst .tar .bz2 .rar .gz .xz .zst .zip .Z .7z)' -d "archive file"
