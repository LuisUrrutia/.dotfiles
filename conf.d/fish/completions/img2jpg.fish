complete --erase -c img2jpg

complete -c img2jpg -f -s h -l help -d "Show help"
complete -c img2jpg -f -s m -l medium -d "Resize to max width 1800"
complete -c img2jpg -f -s s -l small -d "Resize to max width 1080"
complete -c img2jpg -f -r -s w -l max-width -a "1080 1800 2048 2560" -d "Custom max width"
complete -c img2jpg -f -r -s q -l quality -a "80 85 90 95 100" -d "JPEG quality"
complete -c img2jpg -F -r -s o -l output -d "Output JPEG path"
complete -c img2jpg -f -s f -l force -d "Overwrite output"
complete -c img2jpg -F -a '(__fish_complete_suffix .avif .bmp .gif .heic .jpeg .jpg .png .tif .tiff .webp)' -d "Input image"
