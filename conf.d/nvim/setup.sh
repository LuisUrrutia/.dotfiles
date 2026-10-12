#!/usr/bin/env bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0
nvim --headless '+Lazy! restore' +qa
nvim --headless '+Lazy! build telescope-fzf-native.nvim' \
  "+lua local ok, err = pcall(function() require('telescope').load_extension('fzf') end); if not ok then vim.api.nvim_err_writeln(err); vim.cmd.cquit() end" +qa
nvim --headless "+lua if not require('config.blink').ensure() then vim.cmd.cquit() end" +qa
nvim --headless "+lua if not require('config.treesitter').install() then vim.cmd.cquit() end" +qa
