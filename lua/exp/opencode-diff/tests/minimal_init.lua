vim.cmd("set rtp+=" .. vim.fn.stdpath("data") .. "/site")
vim.cmd("packadd plenary.nvim")

vim.opt.rtp:append(vim.fn.getcwd())
