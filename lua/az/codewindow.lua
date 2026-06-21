vim.pack.add({
	"https://github.com/taylrfnt/codewindow.nvim",
})

local codewindow = require('codewindow')
codewindow.setup()
codewindow.apply_default_keybinds()

