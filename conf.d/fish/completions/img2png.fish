complete --erase -c img2png

complete -c img2png -f -s h -l help -d "Show help"
complete -c img2png -f -l quantize -d "Run pngquant after conversion"
complete -c img2png -f -r -l quality -a "80-100 85-100 90-100" -d "pngquant quality"
complete -c img2png -F -r -s o -l output -d "Output PNG path"
complete -c img2png -f -s f -l force -d "Overwrite output"
complete -c img2png -F -a '(__fish_complete_suffix .avif .bmp .gif .heic .jpeg .jpg .png .tif .tiff .webp)' -d "Input image"
