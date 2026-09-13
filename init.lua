require("az")
require("exp")
--core.ui2 is not ready yet floaterm zig build sometimes causes bug remove if too annoying
require('vim._core.ui2').enable()

vim.api.nvim_create_user_command('C2ui', function()
  local ui2 = require('vim._core.ui2')
  ui2.enable({ enable = not ui2.cfg.enable })
end, {})
