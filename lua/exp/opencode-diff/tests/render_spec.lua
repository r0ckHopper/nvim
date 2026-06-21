-- We can't require render directly because it creates Neovim namespaces at module load.
-- Instead we test the individual behaviors with scratch buffers.
local store = require("exp.opencode-diff.store")

-- Helper: create scratch buffer with content
local function scratch_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  return buf
end

-- Create a minimal hunk for testing
local function make_hunk(start, removed, added)
  return {
    id = "test-hunk",
    start = start,
    removed = removed or {},
    added = added or {},
    type = #removed == 0 and "add" or #added == 0 and "delete" or "change",
    resolved = false,
    rejected = false,
    buf = nil,
    end_line = start + math.max(#(removed or {}), #(added or {})) - 1,
  }
end

describe("render", function()
  before_each(function()
    store.clear_all()
  end)

  describe("char_diff", function()
    -- Load render to access char_diff
    -- We test char_diff via the module's redraw/clear API instead
    it("draw_hunk on valid buffer does not error", function()
      local buf = scratch_buf({"line1", "line2", "line3"})
      local h = make_hunk(1, {"old1"}, {"new1"})
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "redraw should not error, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("draw_hunk on add hunk does not error", function()
      local buf = scratch_buf({"line1", "line2"})
      local h = make_hunk(1, {}, {"newline"})
      h.type = "add"
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "add hunk render should not error, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("draw_hunk on delete hunk does not error", function()
      local buf = scratch_buf({"line1", "line2"})
      local h = make_hunk(1, {"oldline"}, {})
      h.type = "delete"
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "delete hunk render should not error, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("clear removes extmarks without error", function()
      local buf = scratch_buf({"line1", "line2", "line3"})
      local h = make_hunk(1, {"old1"}, {"new1"})
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      render.redraw(buf)
      local ok, err = pcall(render.clear, buf)
      assert.is_true(ok, "clear should not error, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("redraw is idempotent", function()
      local buf = scratch_buf({"line1", "line2", "line3"})
      local h = make_hunk(1, {"old1"}, {"new1"})
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      local ok1, err1 = pcall(render.redraw, buf)
      local ok2, err2 = pcall(render.redraw, buf)
      assert.is_true(ok1, "first redraw: " .. tostring(err1))
      assert.is_true(ok2, "second redraw: " .. tostring(err2))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("draw_hunk with start past buffer end does not crash", function()
      local buf = scratch_buf({"line1", "line2", "line3"})
      -- start=50 is well past the 3-line buffer
      local h = make_hunk(50, {"old"}, {"new"})
      h.type = "change"
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "out-of-range hunk should not crash, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("draw_hunk with start=0 does not crash", function()
      local buf = scratch_buf({"line1", "line2", "line3"})
      local h = make_hunk(0, {"old"}, {})
      h.type = "delete"
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "delete hunk with start=0 should not crash, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("draw_hunk with negative start does not crash", function()
      local buf = scratch_buf({"line1", "line2", "line3"})
      local h = make_hunk(-5, {"old"}, {"new"})
      h.type = "change"
      h.buf = buf
      store.register(buf, "/tmp/t", {h})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "negative start hunk should not crash, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("renders multiple change hunks simultaneously", function()
      local buf = scratch_buf({
        "using System;",
        "",
        "namespace Foo;",
        "",
        "class Bar",
        "{",
        "  void Run()",
        "  {",
        "  }",
        "}",
      })
      local h1 = make_hunk(1, {"using System;", ""}, {"using System.IO;", ""})
      h1.type = "change"
      h1.buf = buf
      local h2 = make_hunk(5, {"class Bar"}, {"class Bar //modified"})
      h2.type = "change"
      h2.buf = buf
      local h3 = make_hunk(10, {"}"}, {"} //modified"})
      h3.type = "change"
      h3.buf = buf
      store.clear_buf(buf)
      store.register(buf, "/tmp/t", {h1, h2, h3})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "multi-hunk render should not error, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("renders mixed hunk types simultaneously", function()
      local buf = scratch_buf({
        "keep1",
        "keep2",
        "remove_me",
        "keep3",
        "change_me",
        "keep4",
        "add_after_me",
      })
      local hdel = make_hunk(3, {"remove_me"}, {})
      hdel.type = "delete"
      hdel.buf = buf
      local hchg = make_hunk(5, {"change_me"}, {"changed"})
      hchg.type = "change"
      hchg.buf = buf
      store.clear_buf(buf)
      store.register(buf, "/tmp/t", {hdel, hchg})

      local ok, err = pcall(function()
        require("exp.opencode-diff.render").redraw(buf)
      end)
      assert.is_true(ok, "mixed hunk types should not error, got: " .. tostring(err))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("reject one hunk does not affect other hunk positions", function()
      local buf = scratch_buf({
        "line1",
        "line2",
        "line3",
        "line4",
        "line5",
      })
      local h1 = make_hunk(1, {"old1"}, {"new1"})
      h1.type = "change"
      h1.buf = buf
      local h2 = make_hunk(3, {"old3"}, {"new3"})
      h2.type = "change"
      h2.buf = buf
      store.clear_buf(buf)
      store.register(buf, "/tmp/f.cs", {h1, h2})

      store.resolve(h2.id, true)
      local ok = pcall(function()
        local start_0 = h2.start - 1
        vim.api.nvim_buf_set_text(buf, start_0, 0, start_0 + #h2.added, 0, h2.removed)
      end)
      assert.is_true(ok, "reject should not error")
      assert.are.equal(1, h1.start, "rejecting h2 should not shift h1")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("change hunk highlights unchanged inner lines (BUG: should skip them)", function()
      local buf = scratch_buf({
        "modified1",
        "same2",
        "same3",
        "same4",
        "same5",
      })
      local h = make_hunk(1,
        {"original1", "same2", "same3", "same4", "same5"},
        {"modified1", "same2", "same3", "same4", "same5"}
      )
      h.type = "change"
      h.buf = buf
      store.replace(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})
      local hl_rows = {}
      for _, m in ipairs(marks) do
        local row = m[2]
        local hl = m[4] and m[4].hl_group
        if hl and (hl == "OpencodeDiffChange" or hl == "OpencodeDiffAdd" or hl == "OpencodeDiffDelete") then
          hl_rows[row] = (hl_rows[row] or 0) + 1
        end
      end

      assert.is_not_nil(hl_rows[0], "line 1 (row 0) should be highlighted (changed)")
      assert.is_nil(hl_rows[1], "line 2 (row 1) should NOT be highlighted (same content)")
      assert.is_nil(hl_rows[2], "line 3 (row 2) should NOT be highlighted (same content)")
      assert.is_nil(hl_rows[3], "line 4 (row 3) should NOT be highlighted (same content)")
      assert.is_nil(hl_rows[4], "line 5 (row 4) should NOT be highlighted (same content)")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("change hunk with unchanged inner lines (like App.xaml.cs //hello) should not highlight them", function()
      -- Only line 3 changes, lines 1-2 and 4-5 stay same
      local buf = scratch_buf({
        "aaa unchanged",
        "bbb //hello",
        "ccc changed here",   -- this line changed
        "ddd //hello",
        "eee unchanged",
      })
      local h = make_hunk(1, {
        "aaa unchanged",
        "bbb //hello",
        "ccc original",       -- was this
        "ddd //hello",
        "eee unchanged",
      }, {
        "aaa unchanged",
        "bbb //hello",
        "ccc changed here",   -- now this
        "ddd //hello",
        "eee unchanged",
      })
      h.type = "change"
      h.buf = buf
      store.replace(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})
      local hl_rows = {}
      for _, m in ipairs(marks) do
        local row = m[2]
        local hl = m[4] and m[4].hl_group
        if hl and (hl == "OpencodeDiffChange" or hl == "OpencodeDiffAdd" or hl == "OpencodeDiffDelete") then
          hl_rows[row] = (hl_rows[row] or 0) + 1
        end
      end

      -- Row 0: identical (aaa) — no highlight
      assert.is_nil(hl_rows[0], "row 0 (aaa) unchanged -> no highlight")
      -- Row 1: identical (bbb //hello) — no highlight
      assert.is_nil(hl_rows[1], "row 1 (bbb //hello) unchanged -> no highlight")
      -- Row 2: changed (ccc original → ccc changed here) — highlight
      assert.is_not_nil(hl_rows[2], "row 2 (ccc) changed -> should highlight")
      -- Row 3: identical (ddd //hello) — no highlight
      assert.is_nil(hl_rows[3], "row 3 (ddd //hello) unchanged -> no highlight")
      -- Row 4: identical (eee) — no highlight
      assert.is_nil(hl_rows[4], "row 4 (eee) unchanged -> no highlight")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("change hunk with 3 widely-separated changes highlights correct rows (lines 3,12,14 not 4,5)", function()
      -- 16-line buffer like App.xaml.cs, hunk spans all 16 lines, only 3 actually changed
      local buf = scratch_buf({
        "using Microsoft.Extensions.DependencyInjection;",
        "",
        "namespace OpenSSH; //hello",
        "",
        "public partial class App : Application",
        "{",
        "\tpublic App()",
        "\t{",
        "\t\tInitializeComponent();",
        "\t}",
        "",
        "\tprotected override Window CreateWindow(IActivationState? activationState) //hello",
        "\t{",
        "\t\treturn new Window(new AppShell()); //hello",
        "\t}",
        "}",
      })

      -- 16 removed/added entries, one per buffer line, only 3 differ
      local removed = {
        "using Microsoft.Extensions.DependencyInjection;",
        "",
        "namespace OpenSSH;",
        "",
        "public partial class App : Application",
        "{",
        "\tpublic App()",
        "\t{",
        "\t\tInitializeComponent();",
        "\t}",
        "",
        "\tprotected override Window CreateWindow(IActivationState? activationState)",
        "\t{",
        "\t\treturn new Window(new AppShell());",
        "\t}",
        "}",
      }
      local added = {
        "using Microsoft.Extensions.DependencyInjection;",
        "",
        "namespace OpenSSH; //hello",
        "",
        "public partial class App : Application",
        "{",
        "\tpublic App()",
        "\t{",
        "\t\tInitializeComponent();",
        "\t}",
        "",
        "\tprotected override Window CreateWindow(IActivationState? activationState) //hello",
        "\t{",
        "\t\treturn new Window(new AppShell()); //hello",
        "\t}",
        "}",
      }

      local h = make_hunk(1, removed, added)
      h.type = "change"
      h.buf = buf
      h.first_change_idx = 3
      store.replace(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})
      local hl_rows = {}
      for _, m in ipairs(marks) do
        local row = m[2]
        local hl = m[4] and m[4].hl_group
        if hl and (hl == "OpencodeDiffChange" or hl == "OpencodeDiffAdd" or hl == "OpencodeDiffDelete") then
          hl_rows[row] = (hl_rows[row] or 0) + 1
        end
      end

      -- Line 3 (row 2): correctly highlighted
      assert.is_not_nil(hl_rows[2], "line 3 (row 2) changed — should highlight")
      -- Line 4 (row 3): context, should NOT be highlighted
      assert.is_nil(hl_rows[3], "line 4 (row 3) context — should NOT highlight")
      -- Line 5 (row 4): context, should NOT be highlighted
      assert.is_nil(hl_rows[4], "line 5 (row 4) context — should NOT highlight")
      -- Line 12 (row 11): changed, should be highlighted
      assert.is_not_nil(hl_rows[11], "line 12 (row 11) changed — should highlight")
      -- Line 14 (row 13): changed, should be highlighted
      assert.is_not_nil(hl_rows[13], "line 14 (row 13) changed — should highlight")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("sign appears on every hunk, not just the first", function()
      local buf = scratch_buf({
        "line1",
        "line2",
        "line3",
        "line4",
        "line5",
        "line6",
        "line7",
        "line8",
        "line9",
        "line10",
      })
      -- Two separate hunks: first at line 2, second at line 7
      local h1 = make_hunk(2, {"old2"}, {"new2"})
      h1.type = "change"
      h1.buf = buf
      local h2 = make_hunk(7, {"old7"}, {"new7"})
      h2.type = "change"
      h2.buf = buf

      store.replace(buf, "/tmp/t", {h1, h2})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})

      local sign_rows = {}
      for _, m in ipairs(marks) do
        local details = m[4]
        if details and details.sign_text then
          sign_rows[m[2]] = details.sign_text
        end
      end

      -- Hunk 1: first change at line 2 (row 1)
      assert.is_not_nil(sign_rows[1], "hunk at line 2 (row 1) should have sign")
      -- Hunk 2: first change at line 7 (row 6)
      assert.is_not_nil(sign_rows[6], "hunk at line 7 (row 6) should have sign")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("change hunk shows virt_line with removed content as 'before' line", function()
      local buf = scratch_buf({
        "line1 unchanged",
        "protected override Window CreateWindow(IActivationState? activationState) //hello",
        "line3 unchanged",
      })
      local h = make_hunk(2,
        {"protected override Window CreateWindow(IActivationState? activationState)"},
        {"protected override Window CreateWindow(IActivationState? activationState) //hello"}
      )
      h.type = "change"
      h.buf = buf
      store.replace(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})

      local found_virt = false
      for _, m in ipairs(marks) do
        local details = m[4]
        if details and details.virt_lines then
          for _, vl in ipairs(details.virt_lines) do
            for _, chunk in ipairs(vl) do
              local text = type(chunk) == "table" and chunk[1] or chunk
              if type(text) == "string" and text:find("protected override Window CreateWindow", 1, true) then
                found_virt = true
              end
            end
          end
        end
      end
      assert.is_true(found_virt, "change hunk should have virt_line showing removed content")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("virt_line for change hunk should only strikethrough deleted characters, not the whole line", function()
      local buf = scratch_buf({
        "line1 unchanged",
        "protected override Window CreateWindow(IActivationState? activationState) //hello",
        "line3 unchanged",
      })
      -- old has ^M at end, new has //hello instead. Both have trailing \r (CRLF file).
      local old_text = "protected override Window CreateWindow(IActivationState? activationState)\r"
      local new_text = "protected override Window CreateWindow(IActivationState? activationState) //hello\r"
      local h = make_hunk(2, {old_text}, {new_text})
      h.type = "change"
      h.buf = buf
      store.replace(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})

      local virt_chunks = {}
      for _, m in ipairs(marks) do
        local details = m[4]
        if details and details.virt_lines then
          for _, vl in ipairs(details.virt_lines) do
            for _, chunk in ipairs(vl) do
              if type(chunk) == "table" then
                virt_chunks[#virt_chunks + 1] = { text = chunk[1], hl = chunk[2] }
              end
            end
          end
        end
      end

      assert.are_not.equal(0, #virt_chunks, "should have at least one virt_line chunk")
      -- No characters are deleted (old is a prefix of new), so all should be "same" hl
      for _, c in ipairs(virt_chunks) do
        assert.are_not.equal("OpencodeDiffDeleteText", c.hl, "no deleted chars so no strikethrough")
      end
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("virt_line trailing \\r is stripped from virt_content (not visible to user)", function()
      local buf = scratch_buf({
        "line1",
        "abc\r",
        "line3",
      })
      -- Both old and new have trailing \r (CRLF file). \r is a parsing artifact, not visible in buffer.
      local h = make_hunk(2,
        {"aaa\r"},
        {"abc\r"}
      )
      h.type = "change"
      h.buf = buf
      store.replace(buf, "/tmp/t", {h})

      local render = require("exp.opencode-diff.render")
      pcall(render.redraw, buf)

      local ns_id = vim.api.nvim_get_namespaces()["opencode_diff"]
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns_id, {0, 0}, {-1, -1}, {details = true})

      local has_cr = false
      for _, m in ipairs(marks) do
        local details = m[4]
        if details and details.virt_lines then
          for _, vl in ipairs(details.virt_lines) do
            for _, chunk in ipairs(vl) do
              if type(chunk) == "table" and type(chunk[1]) == "string" then
                if chunk[1]:find("\r", 1, true) then
                  has_cr = true
                end
              end
            end
          end
        end
      end

      assert.is_false(has_cr, "trailing \\r should be stripped from virt_line, not visible to user")
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("reject hunk replaces added lines with removed lines via buf_set_lines", function()
      local buf = scratch_buf({
        "using Microsoft.Extensions.DependencyInjection;",
        "",
        "namespace OpenSSH;",
        "",
        "public partial class App : Application //hello",
        "{",
        "\tpublic App()",
        "\t{",
        "\t\tInitializeComponent();",
        "\t} //hello",
        "",
        "\tprotected override Window CreateWindow(IActivationState? activationState)",
        "\t{",
        "\t\treturn new Window(new AppShell()); //hello",
        "\t}",
        "}",
      })
      local old_lines = {
        "using Microsoft.Extensions.DependencyInjection;", "", "namespace OpenSSH;", "",
        "public partial class App : Application", "{", "\tpublic App()", "\t{", "\t\tInitializeComponent();",
        "\t}", "", "\tprotected override Window CreateWindow(IActivationState? activationState)", "\t{",
        "\t\treturn new Window(new AppShell());", "\t}", "}",
      }
      local h = make_hunk(1, old_lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      h.type = "change"
      h.buf = buf
      store.replace(buf, "/tmp/t.cs", {h})

      -- Simulate reject_hunk logic: replace added range with removed lines
      local start_0 = h.start - 1
      -- Must use nvim_buf_set_lines, NOT nvim_buf_set_text (fails when end_row == line_count)
      local ok, err = pcall(vim.api.nvim_buf_set_lines, buf, start_0, start_0 + #h.added, false, h.removed)
      assert.is_true(ok, "reject should succeed, got error: " .. tostring(err))

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      -- Verify //hello is gone from all lines
      for i = 1, #result do
        assert.is_nil(result[i]:find("//hello", 1, true),
          "line " .. i .. " should not contain //hello after reject, got: " .. result[i])
      end
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
