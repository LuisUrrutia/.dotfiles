function imgoptimize -d "Compress and resize images to max 5K"
    for dependency in fd sips pngquant
        if not command -q $dependency
            echo "Error: $dependency not found."
            return 1
        end
    end

    set -l jpegtran "$HOMEBREW_PREFIX/opt/mozjpeg/bin/jpegtran"
    if not test -x "$jpegtran"
        echo "Error: jpegtran not found at $jpegtran."
        return 1
    end

    set -l max_size 5120
    if test (count $argv) -gt 1
        echo "Usage: imgoptimize [max_size]"
        return 1
    end

    if test (count $argv) -eq 1
        set max_size $argv[1]
    end

    if not string match -qr '^[0-9]+$' -- "$max_size"
        echo "Error: max_size must be a positive integer."
        return 1
    end

    fd -e jpg -e jpeg -e png -x fish -c '
        set -l file $argv[1]
        set -l max_size $argv[2]
        set -l jpegtran $argv[3]

        sips -Z $max_size "$file" --out "$file" >/dev/null 2>/dev/null; or exit 1

        switch (string lower -- "$file")
            case "*.png"
                pngquant --force --quality=90-100 --skip-if-larger --output "$file" -- "$file"
            case "*.jpg" "*.jpeg"
                set -l tmp "$file.tmp"
                "$jpegtran" -copy none -optimize -progressive "$file" > "$tmp"; and mv "$tmp" "$file"; or rm -f "$tmp"
        end
    ' {} $max_size $jpegtran
end
