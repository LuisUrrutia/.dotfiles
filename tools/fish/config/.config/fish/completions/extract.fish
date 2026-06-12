complete --erase -c extract
complete -c extract -F -a '(__fish_complete_suffix .tar.bz2 .tbz2 .tar.gz .tgz .tar.xz .tar .bz2 .rar .gz .zip .Z .7z)' -d "archive file"
