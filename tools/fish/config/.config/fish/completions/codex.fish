complete --erase --command codex

if command -q codex
    command codex completion fish 2>/dev/null | source
end
