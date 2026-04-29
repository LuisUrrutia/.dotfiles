local M = {}

M.parsers = {
    'lua',
    'python',
    'rust',
    'javascript',
    'tsx',
    'typescript',
    'vimdoc',
    'vim',
    'markdown',
    'diff',
    'css',
    'dockerfile',
    'fish',
    'json',
    'yaml',
    'astro',
    'bash'
}

function M.install()
    require("lazy").load({ plugins = { "nvim-treesitter" } })
    vim.cmd("TSInstallSync " .. table.concat(M.parsers, " "))
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        'lua',
        'python',
        'rust',
        'javascript',
        'javascriptreact',
        'typescript',
        'typescriptreact',
        'vimdoc',
        'vim',
        'markdown',
        'diff',
        'css',
        'dockerfile',
        'fish',
        'json',
        'yaml',
        'astro',
        'sh',
    },
    callback = function(args)
        local ok = pcall(vim.treesitter.start, args.buf)
        if not ok then
            return
        end

        vim.wo.foldmethod = 'expr'
        vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    end,
})

return M
