vim.pack.add { "https://github.com/paulo-granthon/hyper.nvim"}
vim.pack.add { "https://github.com/UtkarshVerma/molokai.nvim"}
vim.opt.termguicolors = true

local ok, _ = pcall(vim.cmd, "colorscheme hyper")
if not ok then
	vim.cmd("colorscheme default")
end

-- Make background black and inherits everything else
--vim.cmd([[
--  highlight Normal guibg=#000000 guifg=#FFFFFF
--  highlight Comment guifg=#AAAAAA
--  highlight NormalFloat guibg=NONE ctermbg=NONE
--  highlight SignColumn guibg=NONE ctermbg=NONE
--  highlight VertSplit guibg=NONE ctermbg=NONE
--  highlight StatusLine guibg=NONE ctermbg=NONE
--
--  highlight LineNrAbove guibg=NONE ctermbg=NONE
--  highlight LineNrBelow guibg=NONE ctermbg=NONE
--
--  highlight EndOfBuffer guibg=NONE ctermbg=NONE
--]])

--Makes background transparent
vim.cmd([[
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NormalFloat guibg=NONE ctermbg=NONE
  highlight SignColumn guibg=NONE ctermbg=NONE
  highlight VertSplit guibg=NONE ctermbg=NONE
  highlight StatusLine guibg=NONE ctermbg=NONE

  highlight LineNrAbove guibg=NONE ctermbg=NONE
  highlight LineNrBelow guibg=NONE ctermbg=NONE
  highlight EndOfBuffer guibg=NONE ctermbg=NONE
]])

vim.opt.guicursor = {
	'n-v-c:block-Cursor/lCursor',
	'i-ci-ve:ver25-Cursor/lCursor',
	'r-cr-o:hor20-Cursor/lCursor',
}
