local map = vim.keymap.set
vim.g.mapleader = " "
--help in new tab command
map("n", "<leader>h", ":tab help ", { desc = 'help in new tab command'})

--find and replace command 
map("n", "<leader>fr", ":%s/\\<<C-r><C-w>\\>//g<Left><Left>", { desc = 'find and replace command '})
map('n', '<F2>', ':lua vim.lsp.buf.rename()<CR>')

--move lines in visual mode up and down great for ifs
map("v", "J", ":m '>+1<CR>gv=gv", { desc = 'move lines in visual mode down great for ifs'})
map("v", "K", ":m '<-2<CR>gv=gv", { desc = 'move lines in visual mode up and down great for ifs'})

--map Ctrl c to escape to use for exiting insert mode during visual block mode
map("i", "<C-c>", "<escape>", { desc = 'map Ctrl c to escape to use for exiting insert mode during visual block mode'})

--copy command output to clipboard
map("n", "<leader>c", ":redir @a |<space>| redir END<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>", { desc = 'copy command output to clipboard'})

--paste over visual without yanking
map("x", "<leader>p", '"_dP', { desc = 'paste without yanking'})
map({'n', 'v'}, '<leader>y', '"+y', { desc = 'yank to clipboard'})
map({'n', 'v'}, '<leader>Y', '"+y', { desc = 'yank to clipboard'})
map('n', '<leader>Y', '"+Y', { desc = 'yank line to clipboard'})
map({'n', 'v'}, '<leader>d', '"_d', { desc = 'Delete to void'})
-- Yank line diagnostics (default register, like y)
map("n", "yd", function()
  local diags = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
  if #diags == 0 then
    vim.notify("No diagnostics on this line", vim.log.levels.WARN)
    return
  end
  local lines = vim.iter(diags):map(function(d) return d.message end):totable()
  local text = table.concat(lines, "\n")
  vim.fn.setreg('"', text)  -- default register
  vim.notify("Yanked " .. #diags .. " diagnostic(s)")
end, { desc = "yank line diagnostics (default register)" })

-- Yank line diagnostics to system clipboard via "+yd
map("o", "d", function()
  if vim.v.operator == 'y' and vim.v.register == '+' then
    local diags = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
    if #diags == 0 then
      vim.notify("No diagnostics on this line", vim.log.levels.WARN)
    else
      local lines = vim.iter(diags):map(function(d) return d.message end):totable()
      vim.fn.setreg("+", table.concat(lines, "\n"))
      vim.notify("Yanked " .. #diags .. " diagnostic(s) to clipboard")
    end
    return '<Esc>'
  end
  return 'd'
end, { expr = true, desc = "yank line diagnostics to clipboard (+yd)" })


-- LSP keybindings
map("n", "gd", vim.lsp.buf.definition)
map("n", "gD", vim.lsp.buf.declaration)
map("n", "gR", function()
  require('telescope.builtin').lsp_references(require('telescope.themes').get_cursor({
    jump_type = "never",  -- Don't auto-jump on open
    show_line = true,     -- Show line numbers
  }))
end, { desc = 'LSP references' })

-- map Ctrl n to normal mode to get out when you are on a terminal
map("t", "<C-n>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- map leader v to split with command
map("n", "<leader>v", ":vsplit ", { desc = "vertical split" })

-- run commands in file to terminal
--map('n', '<leader>r', ':.w !bash<CR>', { silent = false })

--Ctrl S to save in both normal and insert mode
map({'n', 'i'}, '<C-S>', '<Cmd>w<CR>' )


vim.api.nvim_create_user_command("Wrap", function()
  vim.opt_local.wrap = not vim.opt_local.wrap:get()
  if vim.opt_local.wrap:get() then
    vim.opt_local.linebreak = true
    vim.opt_local.list = false
  end
end, {})
