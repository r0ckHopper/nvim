vim.pack.add({
	"https://github.com/alexpasmantier/tv.nvim"
})
local tv = require('tv')
tv.setup({
	channels = {
		files = {
			keybinding = 'tv',
			args = { "--preview-size", "70" },
		},
	},
})
