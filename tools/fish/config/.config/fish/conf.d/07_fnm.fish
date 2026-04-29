if command -q fnm
    fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --shell fish | source
end
