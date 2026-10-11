function imgoptimize -d "Compress and resize images to max 5K"
    argparse -n imgoptimize h/help -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: imgoptimize [options] [max_size]"
        printf '%s\n' ""
        printf '%s\n' "Compress and resize JPG, JPEG, and PNG images in the current tree."
        printf '%s\n' "Only replaces an image when the optimized output is smaller."
        printf '\n%s\n' Arguments
        printf '  %-22s %s\n' max_size "max width/height in pixels; default: 5120"
        printf '\n%s\n' Options
        printf '  %-22s %s\n' --help "show this help"
        printf '\n%s\n' Examples
        printf '  %-34s %s\n' imgoptimize "optimize images under the current directory"
        printf '  %-34s %s\n' "cd ~/Pictures/export; imgoptimize" "optimize one image folder"
        printf '  %-34s %s\n' "imgoptimize 3000" "shrink images larger than 3000px wide or tall"
        printf '  %-34s %s\n' "imgoptimize 2048" "target smaller web-ready dimensions"
        return
    end

    set -l max_size 5120
    if test (count $argv) -gt 1
        echo "Usage: imgoptimize [options] [max_size]"
        return 1
    end

    if test (count $argv) -eq 1
        set max_size $argv[1]
    end

    if not string match -qr '^[0-9]+$' -- "$max_size"
        echo "Error: max_size must be a positive integer." >&2
        return 1
    end
    if test "$max_size" -lt 1
        echo "Error: max_size must be a positive integer." >&2
        return 1
    end

    set -l convert (command -s magick; or command -s convert)
    if not set -q convert[1]
        echo "Error: ImageMagick not found."
        return 1
    end
    for dependency in fd identify pngquant
        if not command -q $dependency
            echo "Error: $dependency not found."
            return 1
        end
    end

    set -l jpegtran (command -s jpegtran)
    if set -q DOTFILES_NATIVE_PREFIX; and test -x "$DOTFILES_NATIVE_PREFIX/opt/mozjpeg/bin/jpegtran"
        set jpegtran "$DOTFILES_NATIVE_PREFIX/opt/mozjpeg/bin/jpegtran"
    end
    if not test -x "$jpegtran"
        echo "Error: jpegtran not found at $jpegtran."
        return 1
    end

    fd -e jpg -e jpeg -e png -x fish -c '
        set -l file $argv[1]
        set -l max_size $argv[2]
        set -l jpegtran $argv[3]
        set -l convert $argv[4]
        set -l original_size (wc -c < "$file" | string trim)
        set -l work (mktemp "$file.imgoptimize.XXXXXX"); or exit 1
        cp "$file" "$work"; or begin
            rm -f "$work"
            exit 1
        end

        set -l first_frame (string join "" -- "$file" "[0]")
        set -l metadata (identify -format "%w\n%h\n%m\n" "$first_frame" 2>/dev/null)
        if test (count $metadata) -ne 3
            rm -f "$work"
            exit 1
        end

        if test "$metadata[1]" -gt "$max_size"; or test "$metadata[2]" -gt "$max_size"
            set -l resized (mktemp "$file.imgoptimize.XXXXXX"); or begin
                rm -f "$work"
                exit 1
            end

            "$convert" "$work" -resize "$max_size"x"$max_size>" "$metadata[3]:$resized"; and mv "$resized" "$work"; or begin
                rm -f "$work" "$resized"
                exit 1
            end
        end

        switch (string lower -- "$file")
            case "*.png"
                set -l quantized (mktemp "$file.imgoptimize.XXXXXX"); or begin
                    rm -f "$work"
                    exit 1
                end
                pngquant --force --quality=90-100 --output "$quantized" -- "$work"; and mv "$quantized" "$work"; or rm -f "$quantized"
            case "*.jpg" "*.jpeg"
                set -l optimized (mktemp "$file.imgoptimize.XXXXXX"); or begin
                    rm -f "$work"
                    exit 1
                end
                "$jpegtran" -copy none -optimize -progressive "$work" > "$optimized"; and mv "$optimized" "$work"; or rm -f "$optimized"
        end

        set -l optimized_size (wc -c < "$work" | string trim)
        if test "$optimized_size" -lt "$original_size"
            mv "$work" "$file"
        else
            rm -f "$work"
        end
    ' {} $max_size $jpegtran $convert
end
