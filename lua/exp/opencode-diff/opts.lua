local M = {}

local DEFAULTS = {
  auto_resolve_accepted = false,
  sign_glyphs = {
    add = "┃",
    delete = "▎",
    change = "┃",
  },
}

M.options = vim.deepcopy(DEFAULTS)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
end

return M
