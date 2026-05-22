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
