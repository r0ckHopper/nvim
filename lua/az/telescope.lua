vim.pack.add({ 
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-lua/plenary.nvim",
})
-- Move require and setup together to avoid circular dependency
local telescope = require('telescope')
telescope.setup()
-- Load fzf extension after setup (fzf not working rn)
--telescope.load_extension('fzf')

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>FF', function() builtin.find_files({hidden = true, no_ignore = true}) end , { desc = 'Telescope find hidden files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>FG', function() builtin.live_grep({hidden = true, no_ignore = true}) end , { desc = 'Telescope find hidden files' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = 'Telescope diagnostics' })

