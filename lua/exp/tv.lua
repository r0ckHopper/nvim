vim.pack.add({
	"https://github.com/alexpasmantier/tv.nvim"
})
local tv = require('tv')
tv.setup({
	global_keybindings = {
		channels = '<leader><leader>tv', --default leader tv conflicts with floating window leader t
	},
	channels = {
		files = {
			keybinding = 'tv',
			args = { "--preview-size", "70" },
		},
	},
})
