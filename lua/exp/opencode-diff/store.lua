local M = {}

M.by_buf = {}   ---@type table<integer, table[]>
M.by_file = {}  ---@type table<string, table[]>
M.all = {}      ---@type table<string, table>
M.attached = {} ---@type table<integer, true>
M.resolved_keys = {} ---@type table<integer, table<string, true>>

local counter = 0

function M.hunk_fingerprint(h)
  local removed_str = table.concat(h.removed, "\n")
  local added_str = table.concat(h.added, "\n")
  return vim.fn.sha256(removed_str .. "\0" .. added_str)
end

function M.register(buf, filepath, hunks)
  if not hunks or #hunks == 0 then return end
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

---Replace all hunks for a buffer with new ones.
---Preserves the attached flag to avoid accumulating nvim_buf_attach callbacks.
function M.replace(buf, filepath, hunks)
  if not M.by_buf[buf] then
    M.register(buf, filepath, hunks)
    return
  end

  -- Collect fingerprints of resolved hunks before clearing
  if not M.resolved_keys[buf] then
    M.resolved_keys[buf] = {}
  end
  local collected = 0
  for _, h in ipairs(M.by_buf[buf]) do
    if h.resolved then
      local fp = M.hunk_fingerprint(h)
      M.resolved_keys[buf][fp] = true
      collected = collected + 1
      print("[ODIFF]   RESOLVED: id=" .. tostring(h.id) .. " start=" .. tostring(h.start) .. " removed=[" .. table.concat(h.removed, "|"):sub(1,80) .. "] added=[" .. table.concat(h.added, "|"):sub(1,80) .. "] fp=" .. fp:sub(1,16))
    end
  end
  print("[ODIFF] store.replace buf=" .. buf .. " file=" .. filepath .. ": collected " .. collected .. " resolved fingerprints, incoming=" .. #hunks .. " hunks")

  for _, h in ipairs(M.by_buf[buf]) do
    M.all[h.id] = nil
  end

  for fp, fhunks in pairs(M.by_file) do
    for i = #fhunks, 1, -1 do
      if fhunks[i].buf == buf then
        table.remove(fhunks, i)
      end
    end
  end

  M.by_buf[buf] = {}
  if not M.by_file[filepath] then
    M.by_file[filepath] = {}
  end

  local filtered = 0
  local stored = 0
  for _, hunk in ipairs(hunks) do
    local fp = M.hunk_fingerprint(hunk)
    local matched = M.resolved_keys[buf][fp] ~= nil
    print("[ODIFF]   INCOMING: start=" .. hunk.start .. " removed=[" .. table.concat(hunk.removed, "|"):sub(1,80) .. "] added=[" .. table.concat(hunk.added, "|"):sub(1,80) .. "] fp=" .. fp:sub(1,16) .. " matched=" .. tostring(matched))
    if matched then
      filtered = filtered + 1
      print("[ODIFF]   FILTERED: start=" .. hunk.start .. " removed=[" .. table.concat(hunk.removed, "|"):sub(1,80) .. "] added=[" .. table.concat(hunk.added, "|"):sub(1,80) .. "]")
      goto continue
    end

    counter = counter + 1
    hunk.id = "odiff-" .. counter
    hunk.buf = buf
    hunk.resolved = false
    hunk.rejected = false

    M.by_buf[buf][#M.by_buf[buf] + 1] = hunk
    M.by_file[filepath][#M.by_file[filepath] + 1] = hunk
    M.all[hunk.id] = hunk
    stored = stored + 1
    print("[ODIFF]   STORED: id=" .. hunk.id .. " start=" .. hunk.start .. " removed=[" .. table.concat(hunk.removed, "|"):sub(1,80) .. "] added=[" .. table.concat(hunk.added, "|"):sub(1,80) .. "]")

    ::continue::
  end
  print("[ODIFF] store.replace done: " .. filtered .. " filtered, " .. stored .. " stored, total=" .. #M.by_buf[buf])
end

function M.hunk_at_cursor(buf, line)
  local hunks = M.by_buf[buf]
  if not hunks then return nil end

  for i = #hunks, 1, -1 do
    local h = hunks[i]
    if not h.resolved and line >= h.start and line <= h.end_line then
      return h
    end
  end
  return nil
end

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

function M.resolve(hunk_id, rejected)
  local h = M.all[hunk_id]
  if not h then print("[ODIFF] resolve: hunk " .. tostring(hunk_id) .. " not found"); return end
  h.resolved = true
  h.rejected = rejected and true or false
  print("[ODIFF] resolve: id=" .. tostring(hunk_id) .. " buf=" .. tostring(h.buf) .. " start=" .. tostring(h.start) .. " rejected=" .. tostring(h.rejected))

  -- When accepting, remove the reverse fingerprint from resolved_keys.
  -- This allows the same forward change to reappear as a new hunk
  -- if the agent re-introduces it after a revert was accepted.
  if not h.rejected and h.buf and M.resolved_keys[h.buf] then
    local reverse_fp = M.hunk_fingerprint({removed = h.added, added = h.removed})
    print("[ODIFF] resolve: id=" .. tostring(hunk_id) .. " reverse_fp=" .. tostring(reverse_fp and reverse_fp:sub(1,16)))
    print("[ODIFF] resolve:   removed=[" .. table.concat(h.removed or {}, "|") .. "] added=[" .. table.concat(h.added or {}, "|") .. "]")
    -- Check resolved_keys for matching key and print diagnostic
    local rk = M.resolved_keys[h.buf]
    local existed = rk[reverse_fp] ~= nil
    if not existed and reverse_fp then
      print("[ODIFF] resolve:   DIGNOSTIC: checking resolved_keys for match...")
      local removed_str = table.concat(h.added or {}, "\n")
      local added_str = table.concat(h.removed or {}, "\n")
      print("[ODIFF] resolve:   removed_str hex=" .. M.hex(removed_str))
      print("[ODIFF] resolve:   added_str   hex=" .. M.hex(added_str))
      for k, _ in pairs(rk) do
        -- Found a key? Let's see what it looks like
        local removed_bytes = removed_str:byte(1, math.min(5, #removed_str))
        local fp_bytes = k ~= nil and k:byte(1, math.min(40, #k)) or {}
        print("[ODIFF] resolve:   key first bytes=" .. vim.inspect({k:byte(1, math.min(8, #k))}))
        break
      end
    end
    rk[reverse_fp] = nil
    print("[ODIFF] resolve: existed=" .. tostring(existed))
  end
end

function M.shift_hunks(buf, from_line, delta)
  local hunks = M.by_buf[buf]
  if not hunks then return end
  for _, h in ipairs(hunks) do
    if h.start >= from_line then
      h.start = h.start + delta
      h.end_line = h.end_line + delta
    end
  end
end

---Attach nvim_buf_attach to track user edits that shift hunk positions.
---Called once per buffer.
function M.attach_buf(buf)
  if M.attached[buf] then return end
  M.attached[buf] = true

  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, _, first, last_old, last_new)
      local delta = last_new - last_old
      if delta ~= 0 then
        M.shift_hunks(buf, first + 1, delta)
      end
    end,
    on_detach = function()
      M.attached[buf] = nil
    end,
  })
end

function M.clear_buf(buf)
  local hunks = M.by_buf[buf]
  if not hunks then return end
  for _, h in ipairs(hunks) do
    M.all[h.id] = nil
  end
  M.by_buf[buf] = nil
  M.attached[buf] = nil
  M.resolved_keys[buf] = nil

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
  M.attached = {}
  M.resolved_keys = {}
  counter = 0
end

function M.clear_fingerprints(buf)
  M.resolved_keys[buf] = nil
end

function M.clear_all_fingerprints()
  M.resolved_keys = {}
end

function M.hex(s)
  if not s then return "" end
  local bytes = {}
  for i = 1, math.min(#s, 80) do
    bytes[#bytes + 1] = string.format("%02x", s:byte(i))
  end
  return table.concat(bytes, " ")
end

return M
