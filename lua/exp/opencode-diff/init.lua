local parser = require("exp.opencode-diff.parser")
local store = require("exp.opencode-diff.store")
local render = require("exp.opencode-diff.render")
local opts_mod = require("exp.opencode-diff.opts")

local M = {}

local active = false
local gitsigns_disabled = false

local augroup = vim.api.nvim_create_augroup("OpencodeDiffSession", { clear = true })

local function setup_autocmd()
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "OpencodeEvent:session.diff",
    callback = function(args)
      local diffs = args.data and args.data.event and args.data.event.properties and args.data.event.properties.diff
      print("[ODIFF] session.diff fired. diffs type=" .. type(diffs) .. " val=" .. vim.inspect(diffs):sub(1,200))

      -- Process buffers IN the session.diff diffs list
      local processed = {}
      if diffs then
        for i, fd in ipairs(diffs) do
          print("[ODIFF]   diff entry " .. i .. ": file=" .. tostring(fd.file) .. " has_patch=" .. tostring(fd.patch ~= nil))
          local filepath = fd.file
          if not filepath or not fd.patch then goto continue end

          local fullpath = vim.fn.fnamemodify(filepath, ":p")
          local buf = vim.fn.bufnr(fullpath)
          if buf == -1 then print("[ODIFF]   buf not found for " .. fullpath); goto continue end

          processed[buf] = true

          local hunks = parser.parse(fd.patch, fullpath)
          print("[ODIFF]   parsed " .. #hunks .. " hunks from patch")

          -- Merge revert hunks (accepted changes the agent reverted)
          -- Use fingerprint dedup: skip revert hunk only if same position AND same content
          local revert_count = 0
          local function hunk_matches_patch(r, hunks)
            local rfp = store.hunk_fingerprint(r)
            for _, h in ipairs(hunks) do
              if h.start == r.start and store.hunk_fingerprint(h) == rfp then
                return true
              end
            end
            return false
          end
          for _, r in ipairs(M.detect_reversions(buf)) do
            if not hunk_matches_patch(r, hunks) then
              table.insert(hunks, r)
              revert_count = revert_count + 1
            end
          end
          if revert_count > 0 then print("[ODIFF]   merged " .. revert_count .. " revert hunks") end

          if #hunks == 0 then print("[ODIFF]   no hunks after merge, skipping"); goto continue end

          store.replace(buf, fullpath, hunks)
          store.attach_buf(buf)

          if active then
            render.redraw(buf)
            print("[ODIFF]   rendered " .. #hunks .. " hunks for buf " .. buf)
          end

          ::continue::
        end
      end

      -- Post-loop: check ALL tracked buffers for reversions.
      local tracked = 0
      local checked = 0
      for buf, _ in pairs(store.by_buf) do
        tracked = tracked + 1
        if not processed[buf] then
          checked = checked + 1
          local ok = M.check_reversions(buf)
          print("[ODIFF] post-loop: buf=" .. buf .. " check_reversions=" .. tostring(ok))
        end
      end
      print("[ODIFF] post-loop done: " .. tracked .. " tracked, " .. checked .. " checked (processed=" .. vim.inspect(processed) .. ")")
    end,
    desc = "Track opencode changes for inline diff display",
  })
end

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

function M.is_active()
  return active
end

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

    for buf, _ in pairs(store.by_buf) do
      if vim.api.nvim_buf_is_valid(buf) then
        render.redraw(buf)
      end
    end

    vim.notify("Opencode Diff: on", vim.log.levels.INFO, { title = "opencode" })
  end
end

---Clear all resolved fingerprints so previously accepted/rejected hunks
---reappear on the next session.diff event.
function M.reset()
  store.clear_all_fingerprints()
  vim.notify("Opencode Diff: fingerprints cleared", vim.log.levels.INFO, { title = "opencode" })
end

---Detect reversions of previously accepted hunks.
---When the agent reverts an accepted change, session.diff shows nothing
---(cumulative diff from original is empty). We compare the current buffer
---content against each accepted hunk's "added" content to detect reversions.
---Returns a list of hunk-like tables for store.replace.
function M.detect_reversions(buf)
  if not vim.api.nvim_buf_is_valid(buf) then print("[ODIFF] detect_reversions: buf invalid"); return {} end
  local hunks = store.by_buf[buf]
  if not hunks then print("[ODIFF] detect_reversions buf=" .. buf .. ": no hunks in store"); return {} end
  print("[ODIFF] detect_reversions buf=" .. buf .. ": " .. #hunks .. " total hunks in store")

  local reversions = {}
  for _, h in ipairs(hunks) do
    if h.resolved and not h.rejected then
      local start_0 = h.start - 1
      local n = #h.added
      if n == 0 then goto continue end

      local line_count = vim.api.nvim_buf_line_count(buf)
      if start_0 < 0 or start_0 + n > line_count then
        print("[ODIFF]   hunk id=" .. h.id .. " start=" .. h.start .. " out of range (lines=" .. line_count .. ")")
        goto continue
      end

      local ok, current = pcall(vim.api.nvim_buf_get_lines, buf, start_0, start_0 + n, false)
      if not ok or #current ~= n then
        print("[ODIFF]   hunk id=" .. h.id .. " get_lines failed")
        goto continue
      end

      local changed = false
      local diff_lines = {}
      for i = 1, n do
        if current[i] ~= h.added[i] then
          changed = true
          diff_lines[#diff_lines+1] = "  line " .. (start_0+i) .. ": added=[" .. h.added[i] .. "] buf=[" .. current[i] .. "]"
        end
      end

      if changed then
        print("[ODIFF]   REVERT DETECTED hunk id=" .. h.id .. " start=" .. h.start .. " n=" .. n)
        for _, dl in ipairs(diff_lines) do print("[ODIFF]   " .. dl) end
        table.insert(reversions, {
          type = "change",
          start = h.start,
          end_line = h.start + n - 1,
          removed = vim.deepcopy(h.added),
          added = current,
          first_change_idx = 1,
          filename = h.filename or "",
        })
      end
    end
    ::continue::
  end
  print("[ODIFF] detect_reversions buf=" .. buf .. ": found " .. #reversions .. " reversions")
  return reversions
end

---Check a single buffer for reversions and update store/render if found.
---Returns true if reversions were detected and processed.
function M.check_reversions(buf)
  if not vim.api.nvim_buf_is_valid(buf) then print("[ODIFF] check_reversions: buf invalid"); return false end
  local reversions = M.detect_reversions(buf)
  if #reversions == 0 then print("[ODIFF] check_reversions buf=" .. buf .. ": no reversions"); return false end
  local hlist = store.by_buf[buf]
  local fp = (hlist and #hlist > 0 and hlist[1].filename) or ""
  if not fp or fp == "" then print("[ODIFF] check_reversions: no filepath for buf " .. buf); return false end
  print("[ODIFF] check_reversions buf=" .. buf .. ": calling store.replace with " .. #reversions .. " revert hunks")
  store.replace(buf, fp, reversions)
  store.attach_buf(buf)
  if active then
    render.redraw(buf)
    print("[ODIFF] check_reversions: redrawn buf " .. buf)
  end
  return true
end

function M.next_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.next_unresolved(buf, line)
  if hunk then
    local target = hunk.start + (hunk.first_change_idx or 1) - 1
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  else
    vim.notify("No next unresolved opencode hunk", vim.log.levels.INFO, { title = "opencode" })
  end
end

function M.prev_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.prev_unresolved(buf, line)
  if hunk then
    local target = hunk.start + (hunk.first_change_idx or 1) - 1
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  else
    vim.notify("No previous unresolved opencode hunk", vim.log.levels.INFO, { title = "opencode" })
  end
end

function M.accept_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.hunk_at_cursor(buf, line)
  if not hunk then
    vim.notify("No unresolved hunk at cursor", vim.log.levels.WARN, { title = "opencode" })
    return
  end
  store.resolve(hunk.id, false)
  render.redraw(buf)
end

local function buf_set_lines_safe(buf, start_row, end_row, lines)
  if not vim.bo[buf].modifiable then
    vim.notify("Buffer not modifiable", vim.log.levels.WARN, { title = "opencode" })
    return false
  end
  local ok, err = pcall(vim.api.nvim_buf_set_lines, buf, start_row, end_row, false, lines)
  if not ok then
    vim.notify("Failed to apply reject: " .. tostring(err), vim.log.levels.ERROR, { title = "opencode" })
  end
  return ok
end

function M.reject_hunk()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = store.hunk_at_cursor(buf, line)
  if not hunk then
    vim.notify("No unresolved hunk at cursor", vim.log.levels.WARN, { title = "opencode" })
    return
  end

  local start_0 = hunk.start - 1
  local added_count = #hunk.added

  -- Resolve before text change so on_lines doesn't shift this hunk
  store.resolve(hunk.id, true)

  local ok
  if added_count > 0 then
    ok = buf_set_lines_safe(buf, start_0, start_0 + added_count, hunk.removed)
  else
    ok = buf_set_lines_safe(buf, start_0, start_0, hunk.removed)
  end
  if not ok then
    -- Undo resolve (still unresolved, just can't reject)
    hunk.resolved = false
    hunk.rejected = false
    return
  end

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
  local hunks = store.unresolved(buf)
  table.sort(hunks, function(a, b) return a.start > b.start end)
  for _, h in ipairs(hunks) do
    local start_0 = h.start - 1
    store.resolve(h.id, true)
    local ok
    if #h.added > 0 then
      ok = buf_set_lines_safe(buf, start_0, start_0 + #h.added, h.removed)
    else
      ok = buf_set_lines_safe(buf, start_0, start_0, h.removed)
    end
    if not ok then h.resolved = false; h.rejected = false end
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
        store.resolve(h.id, true)
        local ok
        if #h.added > 0 then
          ok = buf_set_lines_safe(buf, start_0, start_0 + #h.added, h.removed)
        else
          ok = buf_set_lines_safe(buf, start_0, start_0, h.removed)
        end
        if not ok then h.resolved = false; h.rejected = false end
      end
      render.redraw(buf)
    end
  end
end

function M.setup(opts)
  opts_mod.setup(opts)
  setup_autocmd()
end

function M.debug()
  local lines = {
    "=== Opencode Diff Debug ===",
    "active: " .. tostring(active),
    "gitsigns_disabled: " .. tostring(gitsigns_disabled),
    "buffers tracked:",
  }
  for buf, hunks in pairs(store.by_buf) do
    local name = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) or "(invalid)"
    table.insert(lines, "  buf " .. buf .. " (" .. name .. "): " .. #hunks .. " hunks")
    for _, h in ipairs(hunks) do
      table.insert(lines, "    " .. h.id .. ": type=" .. h.type .. " start=" .. h.start .. " resolved=" .. tostring(h.resolved) .. " rejected=" .. tostring(h.rejected))
    end
  end
  local unresolved = 0
  for _, hunks in pairs(store.by_buf) do
    for _, h in ipairs(hunks) do
      if not h.resolved then unresolved = unresolved + 1 end
    end
  end
  table.insert(lines, "total unresolved: " .. unresolved)
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "opencode-diff" })
end

return M
