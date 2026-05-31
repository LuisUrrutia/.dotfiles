function img2jpg -d "Convert an image to an optimized JPEG"
    argparse -n img2jpg h/help m/medium s/small 'w/max-width=' 'q/quality=' 'o/output=' f/force -- $argv
    or return

    if set -q _flag_help
        printf '%s\n' "Usage: img2jpg [options] <image> [-- <magick-args> ...]"
        printf '%s\n' ""
        printf '%s\n' "Convert an image to a stripped, optimized JPEG."
        printf '\n%s\n' Options
        printf '  %-22s %s\n' --medium "resize to max width 1800 and write <base>-medium.jpg"
        printf '  %-22s %s\n' --small "resize to max width 1080 and write <base>-small.jpg"
        printf '  %-22s %s\n' "--max-width <px>" "resize to a custom max width"
        printf '  %-22s %s\n' "--quality <1-100>" "JPEG quality; default: 95"
        printf '  %-22s %s\n' "--output <path>" "write to an explicit output path"
        printf '  %-22s %s\n' --force "overwrite an existing output file"
        printf '  %-22s %s\n' --help "show this help"
        printf '\n%s\n' Examples
        printf '  %s\n' "img2jpg photo.png"
        printf '  %s\n' "img2jpg --medium photo.heic"
        printf '  %s\n' "img2jpg --small --quality 90 photo.png"
        printf '  %s\n' "img2jpg photo.png -- -auto-orient"
        return
    end

    if not command -q magick
        echo "img2jpg: ImageMagick 'magick' is required; install brewfiles/profiles/image" >&2
        return 1
    end

    if test (count $argv) -lt 1
        echo "Usage: img2jpg [options] <image> [-- <magick-args> ...]"
        return 1
    end

    set -l img $argv[1]
    set -l extra $argv[2..-1]

    if not test -f "$img"
        echo "img2jpg: input file not found: $img" >&2
        return 1
    end

    set -l resize_modes
    set -l resize_width
    set -l suffix converted

    if set -q _flag_medium
        set -a resize_modes medium
        set resize_width 1800
        set suffix medium
    end

    if set -q _flag_small
        set -a resize_modes small
        set resize_width 1080
        set suffix small
    end

    if set -q _flag_max_width
        set -a resize_modes max-width
        set resize_width $_flag_max_width[-1]
        set suffix "$resize_width"w
    end

    if test (count $resize_modes) -gt 1
        echo "img2jpg: choose only one resize option" >&2
        return 1
    end

    if test -n "$resize_width"
        if not string match -qr '^[0-9]+$' -- "$resize_width"
            echo "img2jpg: max width must be a positive integer" >&2
            return 1
        end
    end

    set -l quality 95
    if set -q _flag_quality
        set quality $_flag_quality[-1]
    end

    if not string match -qr '^[0-9]+$' -- "$quality"
        echo "img2jpg: quality must be between 1 and 100" >&2
        return 1
    end

    if test "$quality" -lt 1 -o "$quality" -gt 100
        echo "img2jpg: quality must be between 1 and 100" >&2
        return 1
    end

    set -l output
    if set -q _flag_output
        set output $_flag_output[-1]
    else
        set -l base (string replace -r '\.[^.]*$' '' -- "$img")
        set output "$base-$suffix.jpg"
    end

    if test -e "$output"; and not set -q _flag_force
        echo "img2jpg: output exists: $output (use --force to overwrite)" >&2
        return 1
    end

    set -l args "$img" $extra
    if test -n "$resize_width"
        set -l resize_arg (string join '' -- $resize_width 'x>')
        set -a args -resize "$resize_arg"
    end
    set -a args -quality "$quality" -strip "$output"

    magick $args
    or return

    set -l jpegtran
    if set -q HOMEBREW_PREFIX; and test -x "$HOMEBREW_PREFIX/opt/mozjpeg/bin/jpegtran"
        set jpegtran "$HOMEBREW_PREFIX/opt/mozjpeg/bin/jpegtran"
    else
        set jpegtran (command -s jpegtran)
    end

    if set -q jpegtran[1]
        set -l output_dir (dirname "$output")
        set -l tmp (mktemp "$output_dir/img2jpg.XXXXXX")
        or return 1

        "$jpegtran" -copy none -optimize -progressive "$output" >"$tmp"
        and mv "$tmp" "$output"
        or begin
            rm -f "$tmp"
            return 1
        end
    end

    echo "Wrote $output"
end
