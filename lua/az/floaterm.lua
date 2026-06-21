vim.pack.add({
	"https://github.com/voldikss/vim-floaterm"
})

vim.keymap.set("n", "<leader>t",":FloatermToggle<CR>")
--vim.keymap.set("t", "<C-w><C-q>","<C-\\><C-n>:FloatermHide<CR>")
--vim.keymap.set("t", "<C-w>q","<C-\\><C-n>:FloatermHide<CR>") --double binding hide terminal to mimic ^W q functionalityfloa
vim.keymap.set("t", "<C-w>","<C-\\><C-n><C-w>")
vim.keymap.set("n", "<leader>r", function()
  local line = vim.api.nvim_get_current_line():gsub("%%", "\\%%")
  vim.cmd("FloatermNew! " .. line)
end)
