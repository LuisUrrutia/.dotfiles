#!/usr/bin/env bash
set -euo pipefail

nvim --headless '+Lazy! restore' +qa
nvim --headless "+lua if not require('config.blink').ensure() then vim.cmd.cquit() end" +qa
nvim --headless "+lua if not require('config.lsp').ensure() then vim.cmd.cquit() end" +qa
nvim --headless "+lua if not require('config.treesitter').install() then vim.cmd.cquit() end" +qa
