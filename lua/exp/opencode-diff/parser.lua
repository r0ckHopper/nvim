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
        M._finalize(current)
        table.insert(hunks, current)
      end
      current = {
        start = tonumber(hdr),
        removed = {},
        added = {},
        type = nil,
        filepath = filepath,
        first_change_idx = nil,
        _has_removed = false,
        _has_added = false,
      }
    elseif current then
      local first = line:sub(1, 1)
      if first == " " then
        local content = line:sub(2)
        table.insert(current.removed, content)
        table.insert(current.added, content)
      elseif first == "-" then
        current._has_removed = true
        if not current.first_change_idx then
          current.first_change_idx = #current.removed + 1
        end
        table.insert(current.removed, line:sub(2))
      elseif first == "+" then
        current._has_added = true
        if #current.removed > #current.added then
          table.insert(current.added, line:sub(2))
        else
          if not current.first_change_idx then
            current.first_change_idx = #current.removed + 1
          end
          table.insert(current.removed, "")
          table.insert(current.added, line:sub(2))
        end
      end
    end
  end

  if current and (#current.removed > 0 or #current.added > 0) then
    M._finalize(current)
    table.insert(hunks, current)
  end

  local final_hunks = {}
  for _, hunk in ipairs(hunks) do
    local splits = M._split_changes(hunk)
    for _, s in ipairs(splits) do
      table.insert(final_hunks, s)
    end
  end
  return final_hunks
end

function M._finalize(h)
  h.start = math.max(1, h.start)
  while #h.removed > #h.added do
    table.insert(h.added, "")
  end
  while #h.added > #h.removed do
    table.insert(h.removed, "")
  end

  if h._has_added and not h._has_removed then h.type = "add"
  elseif h._has_removed and not h._has_added then h.type = "delete"
  else h.type = "change" end
  h._has_removed = nil
  h._has_added = nil
  h.end_line = h.start + math.max(#h.removed, #h.added) - 1
end

---Split a change hunk into separate hunks per change group.
---A change group is a contiguous range where removed[i] ~= added[i].
---Context runs between changes are split points.
function M._split_changes(h)
  if h.type ~= "change" then return {h} end

  local groups = {}
  local in_group = false
  local gstart = nil
  for i = 1, #h.removed do
    if h.removed[i] ~= h.added[i] then
      if not in_group then
        gstart = i
        in_group = true
      end
    else
      if in_group then
        table.insert(groups, {start = gstart, end_ = i - 1})
        in_group = false
      end
    end
  end
  if in_group then
    table.insert(groups, {start = gstart, end_ = #h.removed})
  end

  if #groups <= 1 then return {h} end

  local result = {}
  for gi, g in ipairs(groups) do
    local nh = {
      start = h.start + g.start - 1,
      removed = {},
      added = {},
      type = "change",
      filepath = h.filepath,
      first_change_idx = 1,
      buf = h.buf,
      resolved = h.resolved,
      rejected = h.rejected,
    }
    for i = g.start, g.end_ do
      table.insert(nh.removed, h.removed[i])
      table.insert(nh.added, h.added[i])
    end
    while #nh.removed > #nh.added do table.insert(nh.added, "") end
    while #nh.added > #nh.removed do table.insert(nh.removed, "") end
    nh.end_line = nh.start + math.max(#nh.removed, #nh.added) - 1
    table.insert(result, nh)
  end
  return result
end

return M
