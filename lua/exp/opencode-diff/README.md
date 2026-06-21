# Opencode Inline Diff — Design Spec

Show inline diffs for changes opencode has already made, using extmarks.
Navigate hunks, accept or reject per-hunk.

## Event Source

Listen to `User OpencodeEvent:session.diff`. The server emits this after
every AI tool cycle finishes (including bash/tool writes). Payload:

```json
{
  "diff": [{
    "file": "relative/path",
    "patch": "unified diff text",
    "additions": 5,
    "deletions": 3,
    "status": "modified"
  }]
}
```

## Plugin Structure

`lua/exp/opencode-diff/` with sub-modules:

| File | Responsibility |
|------|---------------|
| `init.lua` | Public API, autocmd listener, toggle |
| `parser.lua` | Unified diff → `DiffHunk[]` |
| `store.lua` | Per-buffer hunk registry, offset tracking |
| `render.lua` | Extmark drawing (signs, word diff, virt, numhl) |
| `opts.lua` | Default options, user overrides |

`lua/exp/opencode-diff.lua` — thin entry point that requires `init.lua`.

## Data Model

```
DiffHunk {
  id: string            -- "session-{sessionID}-{n}"
  filepath: string      -- absolute path
  buf: integer          -- bufnr
  type: "add"|"delete"|"change"
  removed_lines: string[]
  added_lines: string[]
  start_line: integer   -- 1-indexed, adjusts on prior-hunk reject
  end_line: integer
  resolved: boolean
  rejected: boolean     -- false for accepted
}

HunkStore {
  by_buf: table<b→DiffHunk[]>
  by_file: table<path→DiffHunk[]>
  all: table<id→DiffHunk>
}
```

## Visual Layers

All drawn on namespace `OpencodeDiff`:

| Layer | Extmark | Details |
|-------|---------|---------|
| **Signcolumn** | `sign_text` | `┃` add/change, `_` delete |
| **Numhl** | `hl_group` | Line number highlight on affected lines |
| **Base region** | `hl_group` | Full-line dark green (after) / dark red (before/virt) |
| **Char diff** | `hl_group` inline | Brighter highlight on changed/added/removed chars |
| **Deleted preview** | `virt_lines` | Faded red virt_lines at deletion point |

### Character-level diff algorithm

For each changed line pair (removed[i], added[i]):
1. Align the two strings
2. Find common prefix/suffix
3. Highlight the differing middle section:
   - In the after content (buffer): highlight added/changed chars
   - In the before content (virt_lines for deletions): highlight removed chars

### Highlight groups

```
OpencodeDiffAdd        → dark green bg (full line)
OpencodeDiffDelete     → dark red bg (full line, virt)
OpencodeDiffChange     → dark green bg (full line)
OpencodeDiffText       → brighter green/undercurl (char-level added)
OpencodeDiffDeleteText → brighter red/strikethrough (char-level removed)
```

## Lifecycle

1. `session.diff` arrives → `parser.parse(patch)` → `DiffHunk[]`
2. `store.register(buf, hunks)` → merges into per-buffer list
3. If toggle is active → `render.redraw(buf)` — draws all unresolved
4. User navigates (`]]`/`[[`), accepts/rejects (`<leader>gs`/`<leader>gr`)
5. **Accept:** mark resolved, clear extmarks for that hunk
6. **Reject:** `nvim_buf_set_text` replaces added→removed, mark resolved+rejected
7. On reject: adjust `start_line` for all subsequent hunks in same file by delta

## Edge Cases

| Case | Handling |
|------|----------|
| Buffer unloaded on reject | Refuse, notify |
| User edits within hunk range | Hunk stays valid; reject reverts to original "before" |
| Multiple session.diff events | Merge, don't deduplicate (each is a new batch) |
| Overlapping hunks same line | Sequential in registry; offset tracking handles ordering |
| Buffer has unsaved changes | Reject still applies (revert is already in-memory) |
| Non-existent filepath | Skip silently |

## Toggle

```lua
M.toggle()
```

- **On:** disable gitsigns (`gs.toggle_signs()` + word_diff + numhl + deleted), render all unresolved
- **Off:** clear extmarks, re-enable gitsigns

## Public API

```lua
--- Returned by require("exp.opencode-diff")
--- Keymaps are user's responsibility
{
  next_hunk: fun(),      -- ]] navigate
  prev_hunk: fun(),      -- [[ navigate
  accept_hunk: fun(),    -- <leader>gs
  reject_hunk: fun(),    -- <leader>gr
  accept_buffer: fun(),  -- <leader>gS
  reject_buffer: fun(),  -- <leader>gR
  accept_all: fun(),
  reject_all: fun(),
  toggle: fun(),         -- <leader>gt
  setup: fun(opts),      -- configure
}
```

## Opts

```lua
{
  auto_resolve_accepted = false,  -- if true, skip hunks from edit-permission flow
  sign_glyphs = {
    add = "┃",
    delete = "▎",
    change = "┃",
  },
}
```

## Files Not Touched

The existing opencode.nvim plugin files are never modified. All code lives
in `lua/exp/opencode-diff/` and `lua/exp/opencode-diff.lua`.
