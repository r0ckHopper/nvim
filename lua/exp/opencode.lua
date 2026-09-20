-- edit popup test v2
vim.pack.add({
	"https://github.com/r0ckHopper/opencode.nvim",
	"https://github.com/folke/snacks.nvim",
})
--
require("snacks").setup({
  input = {
    enabled = true, -- Enhances `ask()`
  },
  --picker = {
  --  enabled = true, -- Enhances `select()`
  --  actions = {
  --    ---@param picker snacks.Picker
  --    opencode_send = function(picker)
  --      local items = vim.tbl_map(function(item) ---@param item snacks.picker.Item
  --        return item.file
  --          and require("opencode").format({ path = item.file, from = item.pos, to = item.end_pos })
  --          or item.text
  --      end, picker:selected({ fallback = true }))

  --      require("opencode").prompt(table.concat(items, ", ") .. " ")
  --    end,
  --  },
  --  win = {
  --    input = {
  --      keys = {
  --        ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
  --      },
  --    },
  --  },
  --},
})
--]]

vim.g.opencode_opts = {
	lsp = {
		enabled = true,
	},
	events = {
		permissions = {
			floating = true,
		},
	},
}

--vim.schedule(function()
--	local perm = require("opencode.events.permissions")
--	local orig = perm.request
--	perm.request = function(event, server)
--		require("exp.opencode-permissions").handle(event, server)
--		if not (event.type == "permission.asked" and event.properties.permission ~= "edit") then
--			orig(event, server)
--		end
--	end
--end)
-- 
vim.keymap.set({ "n", "v", "i" }, "<C-h>", function() require("opencode.events.permissions.floating").move_left() end, { desc = "Permission: select left" })
vim.keymap.set({ "n", "v", "i" }, "<C-l>", function() require("opencode.events.permissions.floating").move_right() end, { desc = "Permission: select right" })
vim.keymap.set({ "n", "v", "i" }, "<C-n>", function() require("opencode.events.permissions.floating").next_permission() end, { desc = "Permission: next request" })
vim.keymap.set({ "n", "v", "i" }, "<C-p>", function() require("opencode.events.permissions.floating").prev_permission() end, { desc = "Permission: prev request" })
vim.keymap.set("n", "<C-CR>", function() require("opencode.events.permissions.floating").confirm() end, { desc = "Permission: confirm" })
vim.keymap.set("n", "<leader>op", function() require("opencode.events.permissions.floating").toggle() end, { desc = "Toggle permission window" })



vim.o.autoread = true
vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask opencode…" })
vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end,                          { desc = "Select opencode…" })

vim.keymap.set({ "n", "x" }, "go",  function() return require("opencode").operator("@this ") end,        { desc = "Add range to opencode", expr = true })
vim.keymap.set("n",          "goo", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Add line to opencode", expr = true })

vim.keymap.set("n", "<C-k>", function() require("opencode").command("session.half.page.up") end,   { desc = "Scroll opencode up" })
vim.keymap.set("n", "<C-j>", function() require("opencode").command("session.half.page.down") end, { desc = "Scroll opencode down" })
vim.keymap.set("n", "<C-S-k>", function() require("opencode").command("session.message.previous") end,   { desc = "Scroll opencode up" })
vim.keymap.set("n", "<C-S-j>", function() require("opencode").command("session.message.next") end, { desc = "Scroll opencode down" })

-- You may want these if you use the opinionated `<C-a>` and `<C-x>` keymaps above
vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
vim.keymap.set("n", "_", "<C-x>", { desc = "Decrement under cursor", noremap = true })

-- Check for file changes when OpenCode finishes a response, even if it used
-- bash/sed/etc. (the built-in reload handler only checks on OpencodeEvent:file.edited)
--vim.api.nvim_create_autocmd("User", {
--  pattern = "OpencodeEvent:session.idle",
--  callback = function()
--    vim.schedule(function()
--      vim.cmd("checktime")
--    end)
--  end,
--})


-- Opencode inline diff: tracks changes opencode has already made via session.diff
-- Keymaps dispatch to gitsigns when mode is off, opencode-diff when mode is on
--require("exp.opencode-diff").setup({})
--local od = require("exp.opencode-diff")
--
--vim.keymap.set("n", "<leader>ot", od.toggle, { desc = "Toggle Opencode diff" })
--
--local function with_gs(od_fn, gs_method)
--  return function()
--    if od.is_active() then
--      od_fn()
--    else
--      local ok, gs = pcall(require, "gitsigns")
--      if ok and gs[gs_method] then gs[gs_method]() end
--    end
--  end
--end
--
--vim.keymap.set("n", "]]",         with_gs(od.next_hunk,   "next_hunk"),    { desc = "Next diff hunk" })
--vim.keymap.set("n", "[[",         with_gs(od.prev_hunk,   "prev_hunk"),    { desc = "Prev diff hunk" })
--vim.keymap.set("n", "<leader>os", with_gs(od.accept_hunk, "stage_hunk"),   { desc = "Stage/Accept hunk" })
--vim.keymap.set("n", "<leader>or", with_gs(od.reject_hunk, "reset_hunk"),   { desc = "Reset/Reject hunk" })

