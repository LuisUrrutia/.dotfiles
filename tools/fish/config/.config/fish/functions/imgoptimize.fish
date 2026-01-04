function imgoptimize -d "Compress and resize images to max 5K"
    set -l max_size 5120

    # Allow custom max size as argument
    if test (count $argv) -ge 1
        set max_size $argv[1]
    end

    fd -e jpg -e jpeg -e png -x fish -c '
        set file $argv[1]
        set max_size $argv[2]

        sips -Z $max_size "$file" --out "$file" 2>/dev/null

        switch (string lower "$file")
            case "*.png"
                pngquant --force --quality=90-100 --skip-if-larger --output "$file" -- "$file"
            case "*.jpg" "*.jpeg"
                /opt/homebrew/opt/mozjpeg/bin/jpegtran -copy none -optimize -progressive "$file" > "$file.tmp"; and mv "$file.tmp" "$file"
        end
    ' {} $max_size
end
