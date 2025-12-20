vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.background = "dark"       -- used for highlight colors
vim.opt.ignorecase = true         -- ignore case in search patterns
vim.opt.inccommand = 'split'      -- Live preview of substitution
vim.opt.sidescroll = 1            -- minimum number of columns to scroll horizontal
vim.opt.sidescrolloff = 15        -- min. nr. of columns to left and right of cursor
vim.opt.scrolloff = 8             -- minimum nr. of lines above and below cursor
vim.opt.showmatch = true          -- briefly jump to matching bracket if insert one
vim.opt.showmode = true           -- message on status line to show current mode
vim.opt.smartcase = true          -- no ignore case when pattern has uppercase
vim.opt.visualbell = true         -- use visual bell instead of beeping
vim.opt.wildmode = "list:longest" -- mode for 'wildchar' command-line expansion

-- files matching these patterns are not completed
vim.opt.wildignore:append({
    '*.o', '*.obj', '.git', '*.rbc', '*.pyc', '__pycache__', '*~', '*.class',
    '*.git/*', '*.hg/*', '*.svn/*', '*DS_Store*',
    '*/node_modules/*', '*/.dist/*', '*/.coverage/*'
})

vim.opt.foldenable = false                           -- set to display all folds open
vim.opt.foldmethod = "expr"                          -- folding type
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- use treesitter folding
vim.opt.foldlevelstart = 99                          -- Start with all folds open
vim.opt.linebreak = true                             -- wrap long lines at a blank
vim.opt.number = true                                -- print the line number in front of each line
vim.opt.relativenumber = true                        -- print relative line numbers in front of each line
vim.opt.wrap = true                                  -- lines wrap and continue on the next line


vim.opt.swapfile = false -- whether to use a swapfile for a buffer
vim.opt.expandtab = true -- use spaces when <Tab> is inserted
vim.opt.tabstop = 2      -- number of spaces that <Tab> in file uses
vim.opt.shiftwidth = 2   -- number of spaces to use for (auto)indent step
vim.opt.softtabstop = 2  -- number of spaces that <Tab> uses while editing

vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("state") .. "/undo"

vim.opt.splitbelow = true
vim.opt.splitright = true
