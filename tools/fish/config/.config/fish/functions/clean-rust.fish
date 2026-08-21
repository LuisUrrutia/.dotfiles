function clean-rust -d "Remove Rust game cache"
    set -l cache_root (command getconf DARWIN_USER_CACHE_DIR 2>/dev/null | string trim --right --chars=/)

    if test -z "$cache_root"
        echo "clean-rust: could not resolve the macOS user cache directory" >&2
        return 1
    end

    set -l rust_cache "$cache_root/com.Facepunch-Studios-LTD.Rust"

    if not test -e "$rust_cache"
        echo "Error: Rust cache not found: $rust_cache"
        return 1
    end

    command rm -rf -- "$rust_cache"
end
