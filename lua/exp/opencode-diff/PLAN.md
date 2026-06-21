# Opencode Inline Diff — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone neovim plugin that shows inline diffs using extmarks for changes opencode has already made, with per-hunk accept/reject.

**Architecture:** Listen to `OpencodeEvent:session.diff` SSE events from the opencode server. Parse unified diff patches into structured hunks. Render extmarks (signcolumn, numhl, full-line base color, character-level highlights, virt_lines for deletions). Per-hunk accept/reject with offset tracking. Toggleable mode that disables gitsigns while active.

**Tech Stack:** Neovim Lua, extmarks (`nvim_buf_set_extmark`), `nvim_buf_set_text` for reject, `nvim_create_autocmd` for events.

**Location:** `lua/exp/opencode-diff/` (standalone, no modifications to opencode.nvim plugin files)

---

### Task 1: opts.lua — Default options and setup

**Files:**
- Create: `lua/exp/opencode-diff/opts.lua`

- [ ] **Step 1: Create opts.lua with defaults and merge function**

```lua
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
```

---

### Task 2: parser.lua — Unified diff to hunks

**Files:**
- Create: `lua/exp/opencode-diff/parser.lua`

Parses a unified diff string (standard `git diff` / `diff -u` format) into an array of hunk structs.

A unified diff looks like:
```
--- a/path/to/file
+++ b/path/to/file
@@ -1,3 +1,3 @@
 context
-old line
+new line
 context
```

Each hunk has:
- `type`: "add" (no removed lines), "delete" (no added lines), "change" (both)
- `removed_lines`: string[] — lines starting with `-` (excluding the `-`)
- `added_lines`: string[] — lines starting with `+`
- `start_line`: number — the new-file line number from the hunk header (`+line` in `@@ -a,b +c,d @@`)

- [ ] **Step 1: Create parser.lua**

```lua
local M = {}

---@param patch string The unified diff text
---@param filepath string The file path (for attaching to hunk metadata)
---@return table[] Array of hunk objects
function M.parse(patch, filepath)
  local hunks = {}
  if not patch or #patch == 0 then
    return hunks
  end

  local lines = vim.split(patch, "\n", { plain = true })
  local current_hunk = nil
  local after_line = 0

  for _, line in ipairs(lines) do
    -- Hunk header: @@ -a,b +c,d @@
    local header_start, _, hunk_after = line:find("^@@%s+%-%d+,?%d*%s+%+(%d+),?%d*%s+@@")
    if header_start then
      -- Finalize previous hunk
      if current_hunk and (#current_hunk.removed_lines > 0 or #current_hunk.added_lines > 0) then
        table.insert(hunks, current_hunk)
      end
      after_line = tonumber(hunk_after)
      current_hunk = {
        start_line = after_line,
        removed_lines = {},
        added_lines = {},
        filepath = filepath,
      }
    elseif current_hunk then
      local removed = line:match("^-(.*)")
      local added = line:match("^%(.*)")
      if removed then
        table.insert(current_hunk.removed_lines, removed)
      elseif added then
        table.insert(current_hunk.added_lines, added)
      end
      -- context lines (starting with space) — no-op
    end
  end

  -- Finalize last hunk
  if current_hunk and (#current_hunk.removed_lines > 0 or #current_hunk.added_lines > 0) then
    table.insert(hunks, current_hunk)
  end

  -- Set type on each hunk
  for _, hunk in ipairs(hunks) do
    if #hunk.removed_lines == 0 then
      hunk.type = "add"
    elseif #hunk.added_lines == 0 then
      hunk.type = "delete"
    else
      hunk.type = "change"
    end
    hunk.end_line = hunk.start_line + math.max(#hunk.removed_lines, #hunk.added_lines) - 1
  end

  return hunks
end

return M
```

Wait — there's a bug in the line match. The unified diff lines from the patch use `+` and `-` as first character. Let me fix it:

```lua
      local removed = line:match("^%-(.*)")
      local added = line:match("^%+(.*)")
```

Also note: `---` (file header) and `+++` (file header) and `@@` (hunk header) need to be excluded from being treated as diff content lines. The `---` and `+++` lines won't match `^-(.*)` because they are `---` (three dashes not one), and `^+(.*)` won't match `+++` either for the same reason. However, a line like `---` with exactly three dashes could theoretically appear in a diff... Let me handle this more robustly:

Actually, in standard unified diff format:
- `--- a/file` — old file header (three dashes)
- `+++ b/file` — new file header (three pluses)
- `@@ -a,b +c,d @@` — hunk header
- ` context` — context line (starts with space)
- `-old` — removed line (single dash)
- `+new` — added line (single plus)
- `\-escaped` — escaped line that starts with - or + in context

The `---` and `+++` lines won't be caught by `^%-(.*)` because that pattern matches a single dash. So the parser as written should work. But I should skip the first two lines (the file headers) explicitly to be safe.

Actually let me rewrite it cleaner:

```lua
local M = {}

function M.parse(patch, filepath)
  local hunks = {}
  if not patch or #patch == 0 then return hunks end

  local lines = vim.split(patch, "\n", { plain = true })
  local current = nil

  for _, line in ipairs(lines) do
    local hdr = line:match("^@@%s+%-%d+,?%d*%s+%+(%d+),?%d*%s+@@")
    if hdr then
      if current and (#current.removed > 0 or #current.added > 0) then
        table.insert(hunks, current)
      end
      current = {
        start = tonumber(hdr),
        removed = {},
        added = {},
        type = nil,
        filepath = filepath,
      }
    elseif current then
      local first = line:sub(1, 1)
      if first == "-" then
        table.insert(current.removed, line:sub(2))
      elseif first == "+" then
        table.insert(current.added, line:sub(2))
      end
      -- first == " " → context, skip
      -- first == "\\" → no-newline marker, skip
    end
  end

  if current and (#current.removed > 0 or #current.added > 0) then
    table.insert(hunks, current)
  end

  for _, h in ipairs(hunks) do
    if #h.removed == 0 then h.type = "add"
    elseif #h.added == 0 then h.type = "delete"
    else h.type = "change" end
    h.end_line = h.start + math.max(#h.removed, #h.added) - 1
  end

  return hunks
end

return M
```

---

### Task 3: store.lua — Hunk registry and offset tracking

**Files:**
- Create: `lua/exp/opencode-diff/store.lua`

- [ ] **Step 1: Create store.lua**

```lua
local M = {}

---@type table<integer, table[]>  bufnr → hunk[]
M.by_buf = {}
---@type table<string, table[]>  filepath → hunk[]
M.by_file = {}
---@type table<string, table>    id → hunk
M.all = {}

local counter = 0

---@param buf integer
---@param hunks table[]
function M.register(buf, filepath, hunks)
  if not M.by_buf[buf] then M.by_buf[buf] = {} end
  if not M.by_file[filepath] then M.by_file[filepath] = {} end

  for _, hunk in ipairs(hunks) do
    counter = counter + 1
    hunk.id = "odiff-" .. counter
    hunk.buf = buf
    hunk.resolved = false
    hunk.rejected = false

    M.by_buf[buf][#M.by_buf[buf] + 1] = hunk
    M.by_file[filepath][#M.by_file[filepath] + 1] = hunk
    M.all[hunk.id] = hunk
  end
end

---@param buf integer
---@param line integer 1-indexed cursor line
---@return table|nil
function M.hunk_at_cursor(buf, line)
  local hunks = M.by_buf[buf]
  if not hunks then return nil end

  -- Check in reverse so nested/overlapping hunks return the inner one
  for i = #hunks, 1, -1 do
    local h = hunks[i]
    if not h.resolved and line >= h.start and line <= h.end_line then
      return h
    end
  end
  return nil
end

---@param buf integer
---@return table|nil
function M.next_unresolved(buf, current_line)
  local hunks = M.by_buf[buf]
  if not hunks then return nil end

  local best = nil
  for _, h in ipairs(hunks) do
    if not h.resolved and h.start > current_line then
      if not best or h.start < best.start then
        best = h
      end
    end
  end
  return best
end

---@param buf integer
---@return table|nil
function M.prev_unresolved(buf, current_line)
  local hunks = M.by_buf[buf]
  if not hunks then return nil end

  local best = nil
  for _, h in ipairs(hunks) do
    if not h.resolved and h.start < current_line then
      if not best or h.start > best.start then
        best = h
      end
    end
  end
  return best
end

---@param buf integer
---@return table[]
function M.unresolved(buf)
  local hunks = M.by_buf[buf]
  if not hunks then return {} end
  local result = {}
  for _, h in ipairs(hunks) do
    if not h.resolved then
      result[#result + 1] = h
    end
  end
  return result
end

---@param hunk_id string
---@param rejected boolean
function M.resolve(hunk_id, rejected)
  local h = M.all[hunk_id]
  if not h then return end
  h.resolved = true
  h.rejected = rejected
end

---After a hunk is rejected at `from_line` with a line delta,
---shift all subsequent hunks in the same file.
---@param buf integer
---@param from_line integer
---@param delta integer  (could be negative or positive)
function M.shift_hunks(buf, from_line, delta)
  local hunks = M.by_buf[buf]
  if not hunks then return end
  for _, h in ipairs(hunks) do
    if not h.resolved and h.start >= from_line then
      h.start = h.start + delta
      h.end_line = h.end_line + delta
    end
  end
end

---@param buf integer
function M.clear_buf(buf)
  local hunks = M.by_buf[buf]
  if not hunks then return end
  for _, h in ipairs(hunks) do
    M.all[h.id] = nil
  end
  M.by_buf[buf] = nil
  -- Also clean by_file
  for fp, fhunks in pairs(M.by_file) do
    for i = #fhunks, 1, -1 do
      if fhunks[i].buf == buf then
        table.remove(fhunks, i)
      end
    end
  end
end

function M.clear_all()
  M.by_buf = {}
  M.by_file = {}
  M.all = {}
end

return M
```

---

### Task 4: render.lua — Extmark drawing

**Files:**
- Create: `lua/exp/opencode-diff/render.lua`

- [ ] **Step 1: Create highlight groups**

```lua
local NS = vim.api.nvim_create_namespace("opencode_diff")

local function ensure_hl()
  local hl = vim.api.nvim_set_hl
  hl(0, "OpencodeDiffAdd",        { bg = "#1a3a1a" })  -- dark green
  hl(0, "OpencodeDiffDelete",     { bg = "#3a1a1a" })  -- dark red
  hl(0, "OpencodeDiffChange",     { bg = "#1a3a1a" })
  hl(0, "OpencodeDiffText",       { bg = "#2a5a2a", undercurl = true, sp = "#4aff4a" })
  hl(0, "OpencodeDiffDeleteText", { bg = "#5a2a2a", strikethrough = true, sp = "#ff4a4a" })
  hl(0, "OpencodeDiffAddSign",    { link = "OpencodeDiffAdd" })
  hl(0, "OpencodeDiffDeleteSign", { link = "OpencodeDiffDelete" })
  hl(0, "OpencodeDiffChangeSign", { link = "OpencodeDiffChange" })
end
```

- [ ] **Step 2: Create the render module**

```lua
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
  vim.api.nvim_set_hl(0, "OpencodeDiffChange",     { bg = "#1a3a1a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffText",       { bg = "#2a5a2a", undercurl = true, sp = "#4aff4a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffDeleteText", { bg = "#5a2a2a", strikethrough = true, sp = "#ff4a4a" })
  vim.api.nvim_set_hl(0, "OpencodeDiffAddSign",    { link = "OpencodeDiffAdd" })
  vim.api.nvim_set_hl(0, "OpencodeDiffDeleteSign", { link = "OpencodeDiffDelete" })
  vim.api.nvim_set_hl(0, "OpencodeDiffChangeSign", { link = "OpencodeDiffChange" })
end

---Character-level diff between two strings.
---Returns a list of segments: { { text, type } } where type is "same", "add", "del"
local function char_diff(old_str, new_str)
  -- Simple LCS-based diff at character level
  local m, n = #old_str, #new_str
  local dp = {}
  for i = 0, m do dp[i] = {}; dp[i][0] = 0 end
  for j = 0, n do dp[0][j] = 0 end
  for i = 1, m do
    for j = 1, n do
      if old_str:byte(i) == new_str:byte(j) then
        dp[i][j] = dp[i-1][j-1] + 1
      else
        dp[i][j] = math.max(dp[i-1][j], dp[i][j-1])
      end
    end
  end

  -- Backtrack
  local i, j = m, n
  local segments = {}
  while i > 0 or j > 0 do
    if i > 0 and j > 0 and old_str:byte(i) == new_str:byte(j) then
      table.insert(segments, 1, { text = new_str:sub(j, j), type = "same" })
      i = i - 1; j = j - 1
    elseif j > 0 and (i == 0 or dp[i][j-1] >= dp[i-1][j]) then
      table.insert(segments, 1, { text = new_str:sub(j, j), type = "add" })
      j = j - 1
    else
      table.insert(segments, 1, { text = old_str:sub(i, i), type = "del" })
      i = i - 1
    end
  end
  return segments
end

---Draw a single hunk's extmarks
---@param buf integer
---@param hunk table
local function draw_hunk(buf, hunk)
  local opts = opts_mod.options
  local glyphs = opts.sign_glyphs

  -- Sign column
  local sign_type = hunk.type == "add" and "add" or hunk.type == "delete" and "delete" or "change"
  local sign_hl = "OpencodeDiff" .. sign_type:sub(1, 1):upper() .. sign_type:sub(2) .. "Sign"
  local sign_text = glyphs[sign_type] or "┃"

  local line = hunk.start - 1  -- 0-indexed for extmark

  -- Sign extmark (first line of hunk)
  vim.api.nvim_buf_set_extmark(buf, NS, line, 0, {
    sign_text = sign_text,
    sign_hl_group = sign_hl,
    priority = 80,
  })

  for i = 0, math.max(#hunk.removed, #hunk.added) - 1 do
    local cur_line = hunk.start - 1 + i

    -- Base region highlight
    if hunk.type == "delete" or (hunk.type == "change" and hunk.removed[i+1] and not hunk.added[i+1]) then
      -- virt_text for deleted lines that have no counterpart in added
      if hunk.removed[i+1] then
        vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
          virt_lines = { { {"", "OpencodeDiffDelete"} } },
          priority = 100,
        })
      end
    end

    -- For added/changed lines, draw character-level diffs
    if hunk.added[i+1] and not (hunk.type == "add") then
      local old = hunk.removed[i+1] or ""
      local new = hunk.added[i+1]
      local segments = char_diff(old, new)

      -- Base full-line green
      vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
        hl_group = "OpencodeDiffChange",
        end_row = cur_line,
        end_col = #new,
        priority = 50,
        hl_eol = true,
      })

      -- Char-level highlights on top
      local col = 0
      for _, seg in ipairs(segments) do
        local hl = seg.type == "add" and "OpencodeDiffText" or nil
        if hl then
          vim.api.nvim_buf_set_extmark(buf, NS, cur_line, col, {
            hl_group = hl,
            end_row = cur_line,
            end_col = col + #seg.text,
            priority = 60,
          })
        end
        col = col + #seg.text
      end
    elseif hunk.type == "add" then
      -- Pure add: full line green base, no char highlights
      vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
        hl_group = "OpencodeDiffAdd",
        end_row = cur_line,
        end_col = -1,
        priority = 50,
        hl_eol = true,
      })
    end

    -- Numhl (line number highlight)
    vim.api.nvim_buf_set_extmark(buf, NS, cur_line, 0, {
      number_hl_group = "CursorLineNr",
      priority = 70,
    })
  end
end

---Redraw all unresolved hunks for a buffer
---@param buf integer
function M.redraw(buf)
  ensure_hl()
  M.clear(buf)

  local hunks = store.unresolved(buf)
  for _, hunk in ipairs(hunks) do
    draw_hunk(buf, hunk)
  end
end

---Clear all extmarks for a buffer
---@param buf integer
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
```

---

### Task 5: init.lua — Public API and event listener

**Files:**
- Create: `lua/exp/opencode-diff/init.lua`

- [ ] **Step 1: Create init.lua**

```lua
local parser = require("exp.opencode-diff.parser")
local store = require("exp.opencode-diff.store")
local render = require("exp.opencode-diff.render")
local opts_mod = require("exp.opencode-diff.opts")

local M = {}

local active = false
local gitsigns_disabled = false

-- ──────────────────────────────
-- Session.diff listener
-- ──────────────────────────────

local augroup = vim.api.nvim_create_augroup("OpencodeDiffSession", { clear = true })

local function setup_autocmd()
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "OpencodeEvent:session.diff",
    callback = function(args)
      local diffs = args.data.event.properties.diff
      if not diffs then return end

      for _, fd in ipairs(diffs) do
        local filepath = fd.file
        if not filepath or not fd.patch then goto continue end

        local fullpath = vim.fn.getcwd() .. "/" .. filepath
        local buf = vim.fn.bufnr(fullpath)
        if buf == -1 then goto continue end

        local hunks = parser.parse(fd.patch, fullpath)
        if #hunks == 0 then goto continue end

        store.register(buf, fullpath, hunks)

        if active then
          render.redraw(buf)
        end

        ::continue::
      end
    end,
    desc = "Track opencode changes for inline diff display",
  })
end

-- ──────────────────────────────
-- Gitsigns integration
-- ──────────────────────────────

local function gitsigns_toggle_elements(disable)
  local ok, gs = pcall(require, "gitsigns")
  if not ok then return end

  if disable then
    gs.toggle_signs()
    gs.toggle_word_diff()
    gs.toggle_numhl()
    gs.toggle_deleted()
    gitsigns_disabled = true
  else
    gs.toggle_signs()
    gs.toggle_word_diff()
    gs.toggle_numhl()
    gs.toggle_deleted()
    gitsigns_disabled = false
  end
end

-- ──────────────────────────────
-- Toggle
-- ──────────────────────────────

function M.toggle()
  if active then
    active = false
    render.clear_all()
    if gitsigns_disabled then
      gitsigns_toggle_elements(false)
    end
    vim.notify("Opencode Diff: off", vim.log.levels.INFO, { title = "opencode" })
  else
    active = true
    gitsigns_toggle_elements(true)

    -- Redraw all buffers that have hunks
    for buf, _ in pairs(store.by_buf) do
      if vim.api.nvim_buf_is_valid(buf) then
        render.redraw(buf)
      end
    end

    vim.notify("Opencode Diff: on", vim.log.levels.INFO, { title = "opencode" })
  end
end

-- ──────────────────────────────
-- Navigation
-- ──────────────────────────────

function M.next_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.next_unresolved(buf, line)
  if hunk then
    vim.api.nvim_win_set_cursor(0, { hunk.start, 0 })
  else
    vim.notify("No next unresolved opencode hunk", vim.log.levels.INFO, { title = "opencode" })
  end
end

function M.prev_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.prev_unresolved(buf, line)
  if hunk then
    vim.api.nvim_win_set_cursor(0, { hunk.start, 0 })
  else
    vim.notify("No previous unresolved opencode hunk", vim.log.levels.INFO, { title = "opencode" })
  end
end

-- ──────────────────────────────
-- Accept/Reject
-- ──────────────────────────────

function M.accept_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.hunk_at_cursor(buf, line)
  if not hunk then
    vim.notify("No unresolved hunk at cursor", vim.log.levels.WARN, { title = "opencode" })
    return
  end
  store.resolve(hunk.id, false)  -- rejected = false
  render.redraw(buf)
end

function M.reject_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.hunk_at_cursor(buf, line)
  if not hunk then
    vim.notify("No unresolved hunk at cursor", vim.log.levels.WARN, { title = "opencode" })
    return
  end

  -- Reverse-apply: replace added content with removed content
  local start_0 = hunk.start - 1
  local added_count = #hunk.added
  local removed_count = #hunk.removed

  if added_count > 0 then
    vim.api.nvim_buf_set_text(buf, start_0, 0, start_0 + added_count, 0, hunk.removed)
  else
    -- Pure delete: insert removed lines at deletion point
    vim.api.nvim_buf_set_text(buf, start_0, 0, start_0, 0, hunk.removed)
  end

  store.resolve(hunk.id, true)

  -- Shift subsequent hunks
  local delta = removed_count - added_count
  store.shift_hunks(buf, hunk.start + added_count, delta)

  render.redraw(buf)
end

function M.accept_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local hunks = store.unresolved(buf)
  for _, h in ipairs(hunks) do
    store.resolve(h.id, false)
  end
  render.redraw(buf)
end

function M.reject_buffer()
  local buf = vim.api.nvim_get_current_buf()
  -- Collect and sort by start_line descending so we reject bottom-up
  local hunks = store.unresolved(buf)
  table.sort(hunks, function(a, b) return a.start > b.start end)
  for _, h in ipairs(hunks) do
    local start_0 = h.start - 1
    if #h.added > 0 then
      vim.api.nvim_buf_set_text(buf, start_0, 0, start_0 + #h.added, 0, h.removed)
    else
      vim.api.nvim_buf_set_text(buf, start_0, 0, start_0, 0, h.removed)
    end
    store.resolve(h.id, true)
  end
  render.redraw(buf)
end

function M.accept_all()
  for buf, _ in pairs(store.by_buf) do
    if vim.api.nvim_buf_is_valid(buf) then
      local hunks = store.unresolved(buf)
      for _, h in ipairs(hunks) do
        store.resolve(h.id, false)
      end
      render.redraw(buf)
    end
  end
end

function M.reject_all()
  for buf, _ in pairs(store.by_buf) do
    if vim.api.nvim_buf_is_valid(buf) then
      local hunks = store.unresolved(buf)
      table.sort(hunks, function(a, b) return a.start > b.start end)
      for _, h in ipairs(hunks) do
        local start_0 = h.start - 1
        if #h.added > 0 then
          vim.api.nvim_buf_set_text(buf, start_0, 0, start_0 + #h.added, 0, h.removed)
        else
          vim.api.nvim_buf_set_text(buf, start_0, 0, start_0, 0, h.removed)
        end
        store.resolve(h.id, true)
      end
      render.redraw(buf)
    end
  end
end

-- ──────────────────────────────
-- Setup
-- ──────────────────────────────

function M.setup(opts)
  opts_mod.setup(opts)
  setup_autocmd()
end

return M
```

---

### Task 6: Entry point — lua/exp/opencode-diff.lua

**Files:**
- Create: `lua/exp/opencode-diff.lua`

- [ ] **Step 1: Create thin entry point**

```lua
require("exp.opencode-diff.init")
return require("exp.opencode-diff.init")
```

---

### Self-Review

1. **Spec coverage:** Checked each spec section against tasks:
   - Event source (session.diff) → Task 5 autocmd listener ✓
   - Plugin structure with sub-modules → Tasks 1-6 ✓
   - Data model (DiffHunk, HunkStore) → Task 2 parser, Task 3 store ✓
   - Visual layers (signs, base region, char diff, virt, numhl) → Task 4 render ✓
   - Character-level diff algorithm → Task 4 char_diff ✓
   - Highlight groups → Task 4 ensure_hl ✓
   - Lifecycle (register → redraw → accept/reject → offset shift) → Tasks 3,4,5 ✓
   - Edge cases → handled in code (nil checks, buf validity, empty hunks) ✓
   - Toggle with gitsigns → Task 5 gitsigns_toggle_elements ✓
   - Public API → Task 5 all methods exposed ✓
   - Opts → Task 1 ✓

2. **Placeholder scan:** No TBD, TODO, "implement later", or similar found. All code is complete.

3. **Type consistency:** 
   - `store.register(buf, filepath, hunks)` — called with all three args in init.lua ✓
   - `hunk.start` used consistently across all files (init.lua, render.lua, store.lua) ✓
   - `hunk.removed`/`hunk.added` used consistently ✓
   - `store.resolve(id, rejected)` — second param is boolean, used correctly ✓
   - `render.redraw(buf)` — single param, used correctly ✓
