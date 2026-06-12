function img2png -d "Convert an image to an optimized PNG"
    argparse -n img2png h/help quantize 'quality=' 'o/output=' f/force -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: img2png [options] <image> [-- <magick-args> ...]"
        printf '%s\n' ""
        printf '%s\n' "Convert an image to a stripped, optimized PNG."
        printf '\n%s\n' Options
        printf '  %-22s %s\n' --quantize "run pngquant after conversion for smaller lossy output"
        printf '  %-22s %s\n' "--quality <min-max>" "pngquant quality; default: 90-100; implies --quantize"
        printf '  %-22s %s\n' "--output <path>" "write to an explicit output path"
        printf '  %-22s %s\n' --force "overwrite an existing output file"
        printf '  %-22s %s\n' --help "show this help"
        printf '\n%s\n' Examples
        printf '  %s\n' "img2png photo.jpg"
        printf '  %s\n' "img2png --quantize photo.jpg"
        printf '  %s\n' "img2png --quality 85-100 photo.jpg"
        printf '  %s\n' "img2png photo.jpg -- -resize 1800x\\>"
        return
    end

    if not command -q magick
        echo "img2png: ImageMagick 'magick' is required; install brewfiles/profiles/image" >&2
        return 1
    end

    if test (count $argv) -lt 1
        echo "Usage: img2png [options] <image> [-- <magick-args> ...]"
        return 1
    end

    set -l img $argv[1]
    set -l extra $argv[2..-1]

    if not test -f "$img"
        echo "img2png: input file not found: $img" >&2
        return 1
    end

    set -l output
    if set -q _flag_output
        set output $_flag_output[-1]
    else
        set -l base (string replace -r '\.[^.]*$' '' -- "$img")
        set output "$base-optimized.png"
    end

    if test -e "$output"; and not set -q _flag_force
        echo "img2png: output exists: $output (use --force to overwrite)" >&2
        return 1
    end

    set -l should_quantize false
    if set -q _flag_quantize
        set should_quantize true
    end

    set -l quality 90-100
    if set -q _flag_quality
        set should_quantize true
        set quality $_flag_quality[-1]
    end

    if test "$should_quantize" = true
        if not command -q pngquant
            echo "img2png: pngquant is required for --quantize" >&2
            return 1
        end

        if not string match -qr '^[0-9]{1,3}-[0-9]{1,3}$' -- "$quality"
            echo "img2png: quality must use MIN-MAX, like 90-100" >&2
            return 1
        end

        set -l quality_parts (string split -m1 - -- "$quality")
        if test $quality_parts[1] -lt 0 -o $quality_parts[2] -gt 100 -o $quality_parts[1] -gt $quality_parts[2]
            echo "img2png: quality must be between 0 and 100 with MIN <= MAX" >&2
            return 1
        end
    end

    set -l args "$img" $extra -strip \
        -define png:compression-filter=5 \
        -define png:compression-level=9 \
        -define png:compression-strategy=1 \
        -define png:exclude-chunk=all \
        "$output"

    magick $args
    or return

    if test "$should_quantize" = true
        set -l output_dir (dirname "$output")
        set -l tmp (mktemp "$output_dir/img2png.XXXXXX")
        or return 1

        pngquant --force --quality="$quality" --skip-if-larger --output "$tmp" -- "$output"
        set -l quant_status $status

        if test $quant_status -eq 98
            rm -f "$tmp"
        else if test $quant_status -ne 0
            rm -f "$tmp"
            return $quant_status
        else if test -s "$tmp"
            mv "$tmp" "$output"
            or begin
                rm -f "$tmp"
                return 1
            end
        else
            rm -f "$tmp"
            echo "img2png: pngquant produced an empty output" >&2
            return 1
        end
    end

    echo "Wrote $output"
end
