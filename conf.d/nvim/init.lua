local data = vim.env.MISE_DATA_DIR or ((vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")) .. "/mise")
vim.env.PATH = data .. "/shims:" .. vim.env.PATH

require("config.options")
require("config.lazy")
require("config.treesitter")

vim.keymap.set("n", "gu", "<cmd>diffget //2<CR>")
vim.keymap.set("n", "gh", "<cmd>diffget //3<CR>")
vim.keymap.set("n", "K", function()
  if next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil then
    vim.lsp.buf.hover()
  end
end, { desc = "Show LSP hover" })
