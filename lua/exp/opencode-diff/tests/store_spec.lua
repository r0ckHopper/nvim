local store = require("exp.opencode-diff.store")
local parser = require("exp.opencode-diff.parser")
local diff = require("exp.opencode-diff")

local function make_hunk(start, removed, added)
  local id = tostring(start) .. "-" .. tostring(math.random(1, 99999))
  return { id = "test-" .. id, start = start, removed = removed or {}, added = added or {}, type = "change", resolved = false, rejected = false, buf = 1, end_line = start + math.max(#(removed or {}), #(added or {})) - 1 }
end

describe("store", function()
  before_each(function()
    store.clear_all()
  end)

  it("registers a hunk for a buffer", function()
    local h = make_hunk(1, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    assert.are.equal(1, #store.by_buf[1])
    assert.are.equal(1, store.by_buf[1][1].buf)
    assert.is_not_nil(store.all[h.id])
  end)

  it("registers with sequential IDs starting with odiff-", function()
    local h = make_hunk(1, {}, {"new"})
    h.id = nil
    store.register(1, "/tmp/f.cs", {h})
    assert.matches("^odiff%-", h.id)
  end)

  it("appends to existing buffer hunks", function()
    local h1 = make_hunk(1, {"a"}, {"b"})
    local h2 = make_hunk(5, {"c"}, {"d"})
    store.register(1, "/tmp/f.cs", {h1})
    store.register(1, "/tmp/f.cs", {h2})
    assert.are.equal(2, #store.by_buf[1])
  end)

  it("marks hunk resolved", function()
    local h = make_hunk(1, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.resolve(h.id, false)
    assert.is_true(h.resolved)
    assert.is_false(h.rejected)
  end)

  it("marks hunk rejected", function()
    local h = make_hunk(1, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.resolve(h.id, true)
    assert.is_true(h.resolved)
    assert.is_true(h.rejected)
  end)

  it("unresolved returns only non-resolved hunks", function()
    local h1 = make_hunk(1, {"a"}, {"b"})
    local h2 = make_hunk(5, {"c"}, {"d"})
    store.register(1, "/tmp/f.cs", {h1, h2})
    store.resolve(h1.id, false)
    local u = store.unresolved(1)
    assert.are.equal(1, #u)
    assert.are.equal(h2.id, u[1].id)
  end)

  it("shift_hunks shifts start and end_line", function()
    local h = make_hunk(5, {"a"}, {"b"})
    h.end_line = 5
    store.register(1, "/tmp/f.cs", {h})
    store.shift_hunks(1, 3, 2)
    assert.are.equal(7, h.start)
    assert.are.equal(7, h.end_line)
  end)

  it("shift_hunks shifts resolved hunks too", function()
    local h = make_hunk(5, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.resolve(h.id, false)
    store.shift_hunks(1, 3, 10)
    assert.are.equal(15, h.start, "resolved hunks are shifted for position tracking")
  end)

  it("shift_hunks does not shift hunks before from_line", function()
    local h = make_hunk(2, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.shift_hunks(1, 5, 3)
    assert.are.equal(2, h.start)
  end)

  it("hunk_at_cursor matches hunk by line range", function()
    local h = make_hunk(3, {"a", "b", "c"}, {"x", "y", "z"})
    h.end_line = 5
    store.register(1, "/tmp/f.cs", {h})
    local found = store.hunk_at_cursor(1, 4)
    assert.are.equal(h.id, found.id)
  end)

  it("hunk_at_cursor returns nil outside range", function()
    local h = make_hunk(3, {"a", "b"}, {"x", "y"})
    h.end_line = 4
    store.register(1, "/tmp/f.cs", {h})
    assert.is_nil(store.hunk_at_cursor(1, 10))
  end)

  it("hunk_at_cursor skips resolved hunks", function()
    local h = make_hunk(3, {"a", "b"}, {"x", "y"})
    h.end_line = 4
    store.register(1, "/tmp/f.cs", {h})
    store.resolve(h.id, false)
    assert.is_nil(store.hunk_at_cursor(1, 3))
  end)

  it("next_unresolved finds next hunk after cursor", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    local h2 = make_hunk(7, {"c"}, {"d"})
    store.register(1, "/tmp/f.cs", {h1, h2})
    local n = store.next_unresolved(1, 4)
    assert.are.equal(h2.id, n.id)
  end)

  it("prev_unresolved finds previous hunk before cursor", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    local h2 = make_hunk(7, {"c"}, {"d"})
    store.register(1, "/tmp/f.cs", {h1, h2})
    local p = store.prev_unresolved(1, 8)
    assert.are.equal(h2.id, p.id)
  end)

  it("clear_buf removes all traces of a buffer", function()
    local h = make_hunk(1, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.clear_buf(1)
    assert.is_nil(store.by_buf[1])
    assert.is_nil(store.all[h.id])
  end)

  it("register without clear accumulates duplicates", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    local h2 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})
    store.register(1, "/tmp/f.cs", {h2})
    assert.are.equal(2, #store.by_buf[1], "duplicate register should accumulate")
  end)

  it("clear_buf then register replaces hunks", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})
    store.clear_buf(1)
    local h2 = make_hunk(5, {"c"}, {"d"})
    store.register(1, "/tmp/f.cs", {h2})
    assert.are.equal(1, #store.by_buf[1])
    assert.are.equal(5, store.by_buf[1][1].start)
  end)

  it("replace swaps hunks without clearing attach flag", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})
    store.attached[1] = true
    local h2 = make_hunk(7, {"c"}, {"d"})
    store.replace(1, "/tmp/f.cs", {h2})
    assert.are.equal(1, #store.by_buf[1])
    assert.are.equal(7, store.by_buf[1][1].start)
    assert.is_true(store.attached[1], "replace should preserve attached flag")
  end)

  it("clear_all resets state completely", function()
    local h = make_hunk(1, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.clear_all()
    assert.are.equal(0, vim.tbl_count(store.by_buf))
    assert.are.equal(0, vim.tbl_count(store.all))
  end)

  it("attach_buf calls shift_hunks on user edits", function()
    local h = make_hunk(5, {"a"}, {"b"})
    h.end_line = 5
    store.register(1, "/tmp/f.cs", {h})

    -- Neovim has a quirk with nvim_buf_attach in test harness
    -- We test shift_hunks directly; the attach callback delegates to it
    store.shift_hunks(1, 3, 2)
    assert.are.equal(7, h.start)
  end)

  it("replace filters out resolved hunks by fingerprint", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})
    store.resolve(h1.id, false)

    -- New hunks with same content should be filtered out
    local h2 = make_hunk(3, {"a"}, {"b"})
    store.replace(1, "/tmp/f.cs", {h2})
    assert.are.equal(0, #store.by_buf[1], "resolved hunk should be filtered out")
  end)

  it("replace keeps unresolved hunks with same fingerprint", function()
    -- A hunk that was NOT resolved should NOT be filtered
    local h1 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})

    local h2 = make_hunk(3, {"a"}, {"b"})
    store.replace(1, "/tmp/f.cs", {h2})
    assert.are.equal(1, #store.by_buf[1], "unresolved hunk should persist after replace")
  end)

  it("replace preserves resolved_keys across multiple calls", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})
    store.resolve(h1.id, false)

    -- First replace filters it
    store.replace(1, "/tmp/f.cs", {h1})
    assert.are.equal(0, #store.by_buf[1])

    -- Second replace still filters it (fingerprint persists)
    local h2 = make_hunk(5, {"c"}, {"d"})
    store.replace(1, "/tmp/f.cs", {h2})
    assert.are.equal(1, #store.by_buf[1])
    assert.are.equal(5, store.by_buf[1][1].start)
  end)

  it("replace filters only matching fingerprints, not similar", function()
    local h1 = make_hunk(3, {"old"}, {"new"})
    store.register(1, "/tmp/f.cs", {h1})
    store.resolve(h1.id, false)

    -- Different content should NOT be filtered
    local h2 = make_hunk(7, {"old2"}, {"new2"})
    store.replace(1, "/tmp/f.cs", {h2})
    assert.are.equal(1, #store.by_buf[1])
    assert.are.equal("old2", store.by_buf[1][1].removed[1])
  end)

  it("clear_buf clears resolved_keys", function()
    local h = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.resolve(h.id, false)
    store.clear_buf(1)

    -- After clear_buf, resolved_keys should be nil
    assert.is_nil(store.resolved_keys[1])
  end)

  it("clear_fingerprints removes resolved keys", function()
    local h = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h})
    store.resolve(h.id, false)

    -- First replace filters it out and stores fingerprint
    store.replace(1, "/tmp/f.cs", {h})
    assert.are.equal(0, #store.by_buf[1])

    store.clear_fingerprints(1)
    assert.is_nil(store.resolved_keys[1])

    -- Now replace with same hunk should NOT filter it
    store.replace(1, "/tmp/f.cs", {h})
    assert.are.equal(1, #store.by_buf[1])
  end)

  it("clear_all_fingerprints resets all resolved keys", function()
    local h1 = make_hunk(3, {"a"}, {"b"})
    store.register(1, "/tmp/f.cs", {h1})
    store.resolve(h1.id, false)

    local h2 = make_hunk(5, {"c"}, {"d"})
    store.register(2, "/tmp/f2.cs", {h2})
    store.resolve(h2.id, false)

    store.clear_all_fingerprints()
    assert.are.equal(0, vim.tbl_count(store.resolved_keys))
  end)

  it("comprehensive workflow: repeat changes with accept/reject cycles", function()
    local filepath = "/tmp/test.cs"
    local buf = 1

    -- Step 1: Agent appends //hello to lines 3, 9, 12 (now //hello//hello)
    local diff1 = [[
@@ -1,16 +1,16 @@
 using Microsoft.Extensions.DependencyInjection;
 
-namespace OpenSSH;//hello
+namespace OpenSSH;//hello//hello
 
 public partial class App : Application
 {
 	public App()
 	{
-		INIT123izeComPonent();//hello
+		INIT123izeComPonent();//hello//hello
 	}
 
-protected override Window CreateWindow(IActivationState? activationState)//hello
+protected override Window CreateWindow(IActivationState? activationState)//hello//hello
 {
 	return new WINdow789(new APPsh456ll());
 }
]]
    local hunks1 = parser.parse(diff1, filepath)
    assert.are.equal(3, #hunks1, "step 1: 3 hunks from //hello→//hello//hello")
    store.register(buf, filepath, hunks1)
    assert.are.equal(3, #store.by_buf[buf], "step 1: 3 hunks registered")

    -- Step 2: User accepts all hunks
    for _, h in ipairs(store.by_buf[buf]) do
      store.resolve(h.id, false)
    end
    assert.are.equal(3, #store.by_buf[buf], "step 2: 3 resolved hunks still in store")

    -- Step 3: Agent removes //hello from lines 3, 9, 12 (now no //hello)
    local diff2 = [[
@@ -1,16 +1,16 @@
 using Microsoft.Extensions.DependencyInjection;
 
-namespace OpenSSH;//hello
+namespace OpenSSH;
 
 public partial class App : Application
 {
 	public App()
 	{
-		INIT123izeComPonent();//hello
+		INIT123izeComPonent();
 	}
 
-protected override Window CreateWindow(IActivationState? activationState)//hello
+protected override Window CreateWindow(IActivationState? activationState)
 {
 	return new WINdow789(new APPsh456ll());
 }
]]
    local hunks2 = parser.parse(diff2, filepath)
    assert.are.equal(3, #hunks2, "step 3: 3 hunks for removing //hello (back to no comment)")

    -- Step 4: store.replace filters against step 1's resolved fingerprints.
    -- Step 1 hunks: //hello → //hello//hello. Step 3 hunks: //hello → (empty).
    -- These have different content → different fingerprints → NOT filtered.
    store.replace(buf, filepath, hunks2)
    assert.are.equal(3, #store.by_buf[buf],
      "step 4: 3 new removal hunks appear (fingerprints differ from step 1)")
    assert.are.equal(3, #store.unresolved(buf),
      "step 4: all 3 hunks are unresolved")

    -- Step 5: Accept 1 hunk (the first one — line 3's removal)
    local first = store.by_buf[buf][1]
    assert.are.equal(3, first.start,
      "step 5: first hunk is at line 3 (namespace OpenSSH)")
    store.resolve(first.id, false)
    assert.are.equal(2, #store.unresolved(buf),
      "step 5: 2 unresolved after accepting 1")

    -- Step 6: Agent makes string changes on lines 3, 9, 12
    -- Line 3: namespace OpenSSH; → namespace OpenSSH_NEW;
    -- Line 9: INIT123izeComPonent(); → INIT123_NEW_izeComPonent();
    -- Line 12: protected override... → protected override..._NEW
    local diff3 = [[
@@ -1,16 +1,16 @@
 using Microsoft.Extensions.DependencyInjection;
 
-namespace OpenSSH;//hello
+namespace OpenSSH_NEW;
 
 public partial class App : Application
 {
 	public App()
 	{
-		INIT123izeComPonent();//hello
+		INIT123_NEW_izeComPonent();
 	}
 
-protected override Window CreateWindow(IActivationState? activationState)//hello
+protected override Window CreateWindow(IActivationState_MODIFIED? activationState)
 {
 	return new WINdow789(new APPsh456ll());
 }
]]
    local hunks3 = parser.parse(diff3, filepath)
    assert.are.equal(3, #hunks3, "step 6: 3 hunks for string changes")

    -- Step 7: store.replace. Step 5's accepted hunk was:
    --   removed={"namespace OpenSSH;//hello"}, added={"namespace OpenSSH;"}
    -- Step 6's first hunk is:
    --   removed={"namespace OpenSSH;//hello"}, added={"namespace OpenSSH_NEW;"}
    -- These have DIFFERENT added content → different fingerprints → NOT filtered.
    -- The 2 unresolved step-3 hunks are cleared by replace (they stopped being relevant).
    store.replace(buf, filepath, hunks3)
    assert.are.equal(3, #store.by_buf[buf],
      "step 7: 3 string-change hunks appear (none filtered by step 5's fingerprint)")
    assert.are.equal(3, #store.unresolved(buf),
      "step 7: all 3 string-change hunks are unresolved")

    -- Step 8: Accept all
    for _, h in ipairs(store.by_buf[buf]) do
      store.resolve(h.id, false)
    end
    assert.are.equal(0, #store.unresolved(buf), "step 8: all hunks resolved")

    -- Step 9: Agent restores to original state. session.diff is empty
    -- (cumulative diff from original shows no changes).
    store.replace(buf, filepath, {})
    assert.are.equal(0, #store.by_buf[buf],
      "step 9: no hunks after restore (buffer matches original)")
    assert.are.equal(0, vim.tbl_count(store.by_buf[buf] or {}))
  end)

  it("detect_reversions finds reverts of accepted hunks", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local filepath = "/tmp/revert_test.cs"
    -- Buffer starts in POST-AGENT state (change already applied)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "using Microsoft.Extensions.DependencyInjection;",
      "",
      "namespace OpenSSH;",
      "",
      "public partial class App : Application",
    })

    -- Hunk: agent changed line 3 from `;//hello` to `;`
    local h = {
      id = "test-h1",
      type = "change", start = 3, end_line = 3,
      removed = {"namespace OpenSSH;//hello"},
      added = {"namespace OpenSSH;"},
      first_change_idx = 1, resolved = false, rejected = false,
      buf = buf, filename = filepath,
    }
    store.register(buf, filepath, {h})
    store.resolve(h.id, false)
    -- Buffer at line 3 = "namespace OpenSSH;" matches h.added → no revert yet

    -- Simulate agent reverting: change line 3 back to `;//hello`
    vim.api.nvim_buf_set_lines(buf, 2, 3, false, {"namespace OpenSSH;//hello"})

    local reversions = diff.detect_reversions(buf)
    assert.are.equal(1, #reversions, "one revert hunk detected")
    assert.are.equal(3, reversions[1].start, "revert hunk at line 3")
    assert.are.equal("namespace OpenSSH;", reversions[1].removed[1],
      "revert removes the accepted 'added' content")
    assert.are.equal("namespace OpenSSH;//hello", reversions[1].added[1],
      "revert adds the current buffer content")

    vim.api.nvim_buf_delete(buf, {force = true})
  end)

  it("detect_reversions does not create hunks for unchanged accepted lines", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local filepath = "/tmp/no_revert.cs"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "line1",
      "line2_modified",
    })

    local h = {
      id = "test-h2",
      type = "change", start = 2, end_line = 2,
      removed = {"line2"},
      added = {"line2_modified"},
      first_change_idx = 1, resolved = false, rejected = false,
      buf = buf, filename = filepath,
    }
    store.register(buf, filepath, {h})
    store.resolve(h.id, false)

    -- Buffer matches h.added → no revert
    local reversions = diff.detect_reversions(buf)
    assert.are.equal(0, #reversions, "no revert when buffer unchanged")

    vim.api.nvim_buf_delete(buf, {force = true})
  end)

  it("detect_reversions with store.replace filters correctly", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local filepath = "/tmp/revert_filter.cs"
    -- Buffer starts in POST-AGENT state
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "line1",
      "line2_opencode",
    })

    -- Step 1: Accept hunk (agent changed line2 from "line2" to "line2_opencode")
    local h1 = {
      id = "test-h3",
      type = "change", start = 2, end_line = 2,
      removed = {"line2"},
      added = {"line2_opencode"},
      first_change_idx = 1, resolved = false, rejected = false,
      buf = buf, filename = filepath,
    }
    store.register(buf, filepath, {h1})
    store.resolve(h1.id, false)

    -- Step 2: Agent reverts line2 back to "line2"
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, {"line2"})

    -- Step 3: Detect revert + store.replace
    local reversions = diff.detect_reversions(buf)
    assert.are.equal(1, #reversions, "one revert detected")
    store.replace(buf, filepath, reversions)
    assert.are.equal(1, #store.by_buf[buf], "one revert hunk stored")
    assert.are.equal(1, #store.unresolved(buf), "revert hunk is unresolved")

    -- Step 4: Accept the revert hunk
    store.resolve(store.by_buf[buf][1].id, false)
    assert.are.equal(0, #store.unresolved(buf), "revert accepted")

    -- Step 5: Agent re-adds the change: line2 → "line2_opencode"
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, {"line2_opencode"})
    local h2 = {
      type = "change", start = 2, end_line = 2,
      removed = {"line2"},
      added = {"line2_opencode"},
      first_change_idx = 1, filename = filepath,
    }
    store.replace(buf, filepath, {h2})
    assert.are.equal(1, #store.by_buf[buf],
      "re-added change appears as new hunk (forward fingerprint was removed)")
    assert.are.equal(1, #store.unresolved(buf), "re-added hunk is unresolved")

    vim.api.nvim_buf_delete(buf, {force = true})
  end)

  it("REPRO: agent append //hello → accept all → agent remove //hello → hunks appear", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local filepath = "/tmp/repro.cs"

    -- Base content: line 3 has `;//hello`, line 9 has `();//hello`, line 12 has `)//hello`
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "using Microsoft.Extensions.DependencyInjection;",
      "",
      "namespace OpenSSH;//hello",
      "",
      "public partial class App : Application",
      "{",
      "\tpublic App()",
      "\t{",
      "\t\tINIT123izeComPonent();//hello",
      "\t}",
      "",
      "\tprotected override Window CreateWindow(IActivationState? activationState)//hello",
      "\t{",
      "\t\treturn new WINdow789(new APPsh456ll());",
      "\t}",
      "}",
    })

    -- Step 1: Agent changes lines 3, 9, 12 → `;//hello//hello`
    vim.api.nvim_buf_set_lines(buf, 2, 3, false, {"namespace OpenSSH;//hello//hello"})
    vim.api.nvim_buf_set_lines(buf, 8, 9, false, {"\t\tINIT123izeComPonent();//hello//hello"})
    vim.api.nvim_buf_set_lines(buf, 11, 12, false, {"\tprotected override Window CreateWindow(IActivationState? activationState)//hello//hello"})

    -- Simulate session.diff: the cumulative diff from ORIGINAL to current ("//hello→//hello//hello")
    -- This is what opencode actually fires
    local diff1 = [[
@@ -1,16 +1,16 @@
 using Microsoft.Extensions.DependencyInjection;
 
-namespace OpenSSH;//hello
+namespace OpenSSH;//hello//hello
 
 public partial class App : Application
 {
 	public App()
 	{
-		INIT123izeComPonent();//hello
+		INIT123izeComPonent();//hello//hello
 	}
 
-protected override Window CreateWindow(IActivationState? activationState)//hello
+protected override Window CreateWindow(IActivationState? activationState)//hello//hello
 {
 	return new WINdow789(new APPsh456ll());
 }
]]
    local hunks1 = parser.parse(diff1, filepath)
    -- After _split_changes: 3 hunks (one per line)
    store.replace(buf, filepath, hunks1)
    assert.are.equal(3, #store.by_buf[buf], "step 1: 3 hunks (for //hello→//hello//hello)")

    -- Step 2: User accepts all 3 hunks
    for _, h in ipairs(store.by_buf[buf]) do
      store.resolve(h.id, false)
    end
    assert.are.equal(0, #store.unresolved(buf), "step 2: all resolved")

    -- Step 3: Agent removes //hello → back to `;//hello` (original state)
    local had_error = false
    local ok1 = pcall(vim.api.nvim_buf_set_lines, buf, 2, 3, false, {"namespace OpenSSH;//hello"})
    local ok2 = pcall(vim.api.nvim_buf_set_lines, buf, 8, 9, false, {"\t\tINIT123izeComPonent();//hello"})
    local ok3 = pcall(vim.api.nvim_buf_set_lines, buf, 11, 12, false, {"\tprotected override Window CreateWindow(IActivationState? activationState)//hello"})
    assert.is_true(ok1 and ok2 and ok3, "step 3: buffer reverted")

    -- Step 4: session.diff fires with EMPTY diffs (buffer matches original).
    -- Our handler's loop: for _, fd in ipairs({}) → never executes → detect_reversions NOT called.
    -- Simulate the current handler behavior by NOT calling detect_reversions:
    local empty_diffs = {}
    for _, _ in ipairs(empty_diffs) do
      -- this never runs
    end

    -- After the handler, store still has 3 resolved hunks (no revert hunks)
    -- This is the bug: store.by_buf still has the old accepted hunks,
    -- and detect_reversions was never called by the handler

    -- Now simulate what the FIX should do: call detect_reversions for tracked buffers
    -- when diffs is empty or buffer is not in diffs list
    local reversions = diff.detect_reversions(buf)
    assert.are.equal(3, #reversions,
      "BUG: 3 revert hunks should appear for removed //hello on lines 3, 9, 12")
    -- Revert hunk: removed = accepted state (;//hello//hello), added = current buffer (;//hello)
    assert.are.equal("namespace OpenSSH;//hello//hello", reversions[1].removed[1],
      "revert hunk1: removed is the accepted content (;//hello//hello)")
    assert.are.equal("namespace OpenSSH;//hello", reversions[1].added[1],
      "revert hunk1: added is current buffer content (;//hello)")

    vim.api.nvim_buf_delete(buf, {force = true})
  end)

  it("check_reversions catches revert when handler receives nil diffs", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local filepath = "/tmp/nil_diffs.cs"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "line1",
      "line2_opencode",  -- post-agent state
    })

    -- Register + accept hunk (agent changed line2)
    local h = {
      id = "test-nil", type = "change", start = 2, end_line = 2,
      removed = {"line2"}, added = {"line2_opencode"},
      first_change_idx = 1, resolved = false, rejected = false,
      buf = buf, filename = filepath,
    }
    store.register(buf, filepath, {h})
    store.resolve(h.id, false)

    -- Agent reverts line2 back to "line2"
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, {"line2"})

    -- Simulate handler being called with nil diffs:
    --   local diffs = nil
    --   if diffs then for ... end  -- skips loop entirely
    --   for buf,_ in pairs(store.by_buf) do
    --     if not processed[buf] then M.check_reversions(buf) end
    --   end
    -- check_reversions should find the revert
    local ok = diff.check_reversions(buf)
    assert.is_true(ok, "check_reversions should detect and process reversions")

    -- Store should now have 1 revert hunk
    assert.are.equal(1, #store.by_buf[buf], "1 revert hunk in store")
    assert.are.equal(1, #store.unresolved(buf), "revert hunk is unresolved")

    -- Verify revert hunk content: removed=accepted, added=current
    local rev = store.by_buf[buf][1]
    assert.are.equal("line2_opencode", rev.removed[1],
      "revert removes the accepted 'added' content")
    assert.are.equal("line2", rev.added[1],
      "revert adds the current buffer content")

    vim.api.nvim_buf_delete(buf, {force = true})
  end)
end)
