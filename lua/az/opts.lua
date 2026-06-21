vim.opt.swapfile = false
vim.o.winborder = 'bold'
vim.opt.number = true
--vim.opt.relativenumber = false
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

--absolute + relative works well but breaks terminal
--vim.opt.statuscolumn = "%s%{v:lnum} %{v:relnum}"

-- netrw_liststyle to tree and netrw_banner to false
--vim.g.netrw_liststyle = 3
--vim.g.netrw_banner = 0

--diagnostics opt
vim.diagnostic.config({ virtual_text = true })

-- diff behavior dunno how to use
vim.opt.diffopt = {
	"internal",
	"filler",
	"closeoff",
	"indent-heuristic",
	"inline:char",
	"linematch:40",
}

