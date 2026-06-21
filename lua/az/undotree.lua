vim.cmd.packadd('nvim.undotree')
vim.keymap.set('n', '<leader>u', vim.cmd.Undotree, { desc = 'Toggle undotree' })

vim.o.undofile = true
local undodir = vim.fn.stdpath('state') .. '/undo'
vim.fn.mkdir(undodir, 'p')
vim.o.undodir = undodir
