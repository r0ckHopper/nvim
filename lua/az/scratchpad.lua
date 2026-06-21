vim.pack.add({
	"https://github.com/athar-qadri/scratchpad.nvim"
})
local scratchpad = require("scratchpad")
scratchpad:setup({
  settings = {
    sync_on_ui_close = true,
    title = "My Scratch Pad"
  },
  default = {
  --here you specify project root identifiers (Cargo.toml, package.json, blah-blah-blah)
  --or let your man do the job
    root_patterns = { "build.zig", ".git", "package.json", "README.md" },
  },
})
vim.keymap.set('n', "<leader>s", function() scratchpad.ui:new_scratchpad() end);
