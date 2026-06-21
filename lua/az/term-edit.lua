vim.pack.add({
	'https://github.com/chomosuke/term-edit.nvim'
})
require 'term-edit'.setup{
	prompt_end = '%$ ',
	--feedkeys_delay = 20000,
}
