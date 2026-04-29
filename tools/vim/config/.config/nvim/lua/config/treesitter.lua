local parsers = {
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

require 'nvim-treesitter'.install(parsers)

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
