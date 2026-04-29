status is-interactive; or return

if command -q fnm
    fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --shell fish | source
end
