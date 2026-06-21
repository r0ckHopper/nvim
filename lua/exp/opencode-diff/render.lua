local store = require("exp.opencode-diff.store")
local opts_mod = require("exp.opencode-diff.opts")

local M = {}

local NS = vim.api.nvim_create_namespace("opencode_diff")
local hl_done = false

local function ensure_hl()
  if hl_done then return end
  hl_done = true
  vim.api.nvim_set_hl(0, "OpencodeDiffAdd",        { bg = "#1a3a1a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffDelete",     { bg = "#3a1a1a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffChange",     { bg = "#1a3a2a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffText",       { bg = "#2a5a2a", undercurl = true, sp = "#4aff4a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffDeleteText", { bg = "#5a2a2a", strikethrough = true, sp = "#ff4a4a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffAddSign",    { link = "OpencodeDiffAdd" })
  vim.api.nvim_set_hl(0, "OpencodeDiffDeleteSign", { link = "OpencodeDiffDelete" })
  vim.api.nvim_set_hl(0, "OpencodeDiffChangeSign", { link = "OpencodeDiffChange" })
end

---Character-level diff using vim.diff with each character on its own line.
local function char_diff(old_str, new_str)
  if old_str == new_str then return {{ text = new_str, type = "same" }} end
  if #old_str == 0 then
    local segs = {}
    for i = 1, #new_str do segs[i] = { text = new_str:sub(i, i), type = "add" } end
    return segs
  end
  if #new_str == 0 then
    local segs = {}
    for i = 1, #old_str do segs[i] = { text = old_str:sub(i, i), type = "del" } end
    return segs
  end

  local function to_chars(s) return (s:gsub(".", "%0\n")) end
  local hunks = vim.diff(to_chars(old_str), to_chars(new_str), { result_type = "indices" })

  local old_arr = {}
  for i = 1, #old_str do old_arr[i] = old_str:sub(i, i) end
  local new_arr = {}
  for i = 1, #new_str do new_arr[i] = new_str:sub(i, i) end

  local segments = {}
  local oi, ni = 1, 1

  for _, hunk in ipairs(hunks) do
    local sa, ca, sb, cb = hunk[1], hunk[2], hunk[3], hunk[4]

    while oi < sa and ni < sb do
      table.insert(segments, { text = new_arr[ni], type = "same" })
      oi = oi + 1
      ni = ni + 1
    end

    while oi < sa do
      table.insert(segments, { text = new_arr[ni], type = "same" })
      oi = oi + 1
      ni = ni + 1
    end

    while ni < sb do
      table.insert(segments, { text = new_arr[ni], type = "same" })
      oi = oi + 1
      ni = ni + 1
    end

    for _ = 1, ca do
      table.insert(segments, { text = old_arr[oi], type = "del" })
      oi = oi + 1
    end

    for _ = 1, cb do
      table.insert(segments, { text = new_arr[ni], type = "add" })
      ni = ni + 1
    end
  end

  while oi <= #old_arr and ni <= #new_arr do
    table.insert(segments, { text = new_arr[ni], type = "same" })
    oi = oi + 1
    ni = ni + 1
  end

  return segments
end

---Get the byte length of a buffer line.
local function line_len(buf, row)
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, row, row + 1, false)
  if not ok or not lines or #lines == 0 then return 0 end
  return #(lines[1] or "")
end

---Draw a single hunk's extmarks.
---Uses deterministic extmark IDs so updated hunks replace old marks.
---Skips lines past the buffer end to avoid crashes.
local function draw_hunk(buf, hunk)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local opts = opts_mod.options
  local glyphs = opts.sign_glyphs

  local sign_type = hunk.type == "add" and "add" or hunk.type == "delete" and "delete" or "change"
  local sign_hl = "OpencodeDiff" .. sign_type:sub(1, 1):upper() .. sign_type:sub(2) .. "Sign"
  local sign_text = glyphs[sign_type] or "┃"

  local first_change_idx = hunk.first_change_idx or 1
  local first_line = hunk.start - 1 + first_change_idx - 1

  if first_line >= 0 and first_line < line_count then
    vim.api.nvim_buf_set_extmark(buf, NS, first_line, 0, {
      id = first_line * 10000 + 9999,
      sign_text = sign_text,
      sign_hl_group = sign_hl,
      priority = 80,
    })
  end

  for i = 0, math.max(#hunk.removed, #hunk.added) - 1 do
    local cur_line = hunk.start - 1 + i
    if cur_line < 0 or cur_line >= line_count then break end

    local llen = line_len(buf, cur_line)

    if hunk.type == "add" then
      if llen > 0 then
        vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
          id = cur_line * 10000 + 1,
          hl_group = "OpencodeDiffAdd",
          end_col = llen,
          priority = 50,
        })
      end
    elseif hunk.type == "delete" then
      if hunk.removed[i+1] then
        vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
          id = cur_line * 10000 + 1,
          virt_lines = { { { hunk.removed[i+1], "OpencodeDiffDelete" } } },
          priority = 100,
          virt_lines_above = false,
        })
      end
    elseif hunk.type == "change" then
      local old = hunk.removed[i+1] or ""
      local new = hunk.added[i+1] or ""

      if old ~= new then
        if #old > 0 then
          local function strip_cr(s) return (s:gsub("\r$", "")) end
          local segments = char_diff(strip_cr(old), strip_cr(new))
          local virt_chunks = {}
          local last_type = nil
          for _, seg in ipairs(segments) do
            if seg.type == "same" or seg.type == "del" then
              local hl = seg.type == "same" and "OpencodeDiffDelete" or "OpencodeDiffDeleteText"
              if last_type == seg.type and #virt_chunks > 0 then
                virt_chunks[#virt_chunks][1] = virt_chunks[#virt_chunks][1] .. seg.text
              else
                virt_chunks[#virt_chunks + 1] = { seg.text, hl }
              end
              last_type = seg.type
            end
          end
          if #virt_chunks > 0 then
            vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
              id = cur_line * 10000 + 3,
              virt_lines = { virt_chunks },
              priority = 100,
              virt_lines_above = true,
            })
          end
        end

        if llen > 0 then
          vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
            id = cur_line * 10000 + 1,
            hl_group = "OpencodeDiffChange",
            end_col = llen,
            priority = 50,
          })
        end
      end

      if new and #new > 0 then
        local segments = char_diff(old, new)
        local col = 0
        for si, seg in ipairs(segments) do
          if seg.type == "add" then
            local end_col = math.min(col + #seg.text, llen)
            if end_col > col then
              vim.api.nvim_buf_set_extmark(buf, NS, cur_line, col, {
                id = cur_line * 10000 + si + 100,
                hl_group = "OpencodeDiffText",
                end_col = end_col,
                priority = 60,
              })
            end
            col = col + #seg.text
          elseif seg.type == "same" then
            col = col + #seg.text
          end
        end
      end
    end

    vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
      id = cur_line * 10000 + 2,
      number_hl_group = "CursorLineNr",
      priority = 70,
    })
  end
end

function M.redraw(buf)
  ensure_hl()
  M.clear(buf)

  local hunks = store.unresolved(buf)
  for _, hunk in ipairs(hunks) do
    draw_hunk(buf, hunk)
  end
end

function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
end

function M.clear_all()
  for buf, _ in pairs(store.by_buf) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    end
  end
end

return M
