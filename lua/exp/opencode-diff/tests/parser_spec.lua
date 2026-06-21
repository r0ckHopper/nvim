local parser = require("exp.opencode-diff.parser")

describe("parser", function()
  it("returns empty list for nil patch", function()
    local hunks = parser.parse(nil, "/tmp/test.cs")
    assert.are.equal(0, #hunks)
  end)

  it("returns empty list for empty string", function()
    local hunks = parser.parse("", "/tmp/test.cs")
    assert.are.equal(0, #hunks)
  end)

  it("parses a single add hunk", function()
    local patch = [[
@@ -0,0 +1,1 @@
+hello
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(1, #hunks)
    assert.are.equal("add", hunks[1].type)
    assert.are.equal(1, hunks[1].start)
    assert.are.equal(1, #hunks[1].removed)
    assert.are.equal(1, #hunks[1].added)
    assert.are.equal("hello", hunks[1].added[1])
  end)

  it("parses a single delete hunk", function()
    local patch = [[
@@ -1,1 +0,0 @@
-hello
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(1, #hunks)
    assert.are.equal("delete", hunks[1].type)
    assert.are.equal(1, hunks[1].start)
    assert.are.equal(1, #hunks[1].removed)
    assert.are.equal(1, #hunks[1].added)
    assert.are.equal("hello", hunks[1].removed[1])
  end)

  it("parses a change hunk", function()
    local patch = [[
@@ -1,2 +1,2 @@
-a
+b
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(1, #hunks)
    assert.are.equal("change", hunks[1].type)
    assert.are.equal(1, #hunks[1].removed)
    assert.are.equal(1, #hunks[1].added)
    assert.are.equal("a", hunks[1].removed[1])
    assert.are.equal("b", hunks[1].added[1])
  end)

  it("accounts for context lines before changes", function()
    local patch = [[
@@ -2,3 +2,3 @@
 a
-b
+c
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(1, #hunks)
    assert.are.equal("change", hunks[1].type)
    -- start from hdr (2), context lines included in arrays
    assert.are.equal(2, hunks[1].start)
    assert.are.equal(2, #hunks[1].removed)
    assert.are.equal(2, #hunks[1].added)
  end)

  it("handles hunks with differing removed/added counts", function()
    local patch = [[
@@ -1,3 +1,5 @@
+0
 a
-b
+c
+d
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(2, #hunks, "differing counts produce 2 change groups")
    assert.are.equal(1, #hunks[1].removed)
    assert.are.equal(2, #hunks[2].removed)
    assert.are.equal(1, #hunks[1].added)
    assert.are.equal(2, #hunks[2].added)
  end)

  it("skips no-newline-at-eof marker", function()
    local patch = [[
@@ -1,1 +1,1 @@
-old
+new
\ No newline at end of file
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(1, #hunks)
    assert.are.equal(1, #hunks[1].removed)
    assert.are.equal(1, #hunks[1].added)
  end)

  it("computes end_line correctly", function()
    local patch = [[
@@ -1,3 +1,3 @@
-a
+b
-c
+d
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(1, #hunks)
    assert.are.equal(hunks[1].start + 1, hunks[1].end_line)
  end)

  it("splits change hunk with context lines into individual hunks per change", function()
    local patch = [[
@@ -1,16 +1,16 @@
 using Microsoft.Extensions.DependencyInjection;
 
 namespace OpenSSH;
 
-public partial class App : Application
+public partial class App : Application //hello
 {
 	public App()
 	{
 		InitializeComponent();
-	}
+	} //hello
 
 	protected override Window CreateWindow(IActivationState? activationState)
 	{
-		return new Window(new AppShell());
+		return new Window(new AppShell()); //hello
 	}
 }
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(3, #hunks, "should split 3 changes into 3 hunks")
    local h = hunks[1]
    -- Each hunk should include some context around the change
    assert.is_not_nil(h.removed[1])
    assert.is_not_nil(h.added[1])
  end)

  it("parses multiple hunks", function()
    local patch = [[
@@ -1,1 +1,1 @@
-a
+b
@@ -5,1 +5,1 @@
-c
+d
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    assert.are.equal(2, #hunks)
    assert.are.equal(1, hunks[1].start)
    assert.are.equal(5, hunks[2].start)
  end)

  it("splits change hunk by individual change groups for per-change accept/reject", function()
    local patch = [[
@@ -1,16 +1,16 @@
 using Microsoft.Extensions.DependencyInjection;
 
 namespace OpenSSH;
 
-public partial class App : Application
+public partial class App : Application //hello
 {
 	public App()
 	{
 		InitializeComponent();
-	}
+	} //hello
 
 	protected override Window CreateWindow(IActivationState? activationState)
 	{
-		return new Window(new AppShell());
+		return new Window(new AppShell()); //hello
 	}
 }
]]
    local hunks = parser.parse(patch, "/tmp/test.cs")
    -- Should be split into 3 hunks, one per change
    assert.are.equal(3, #hunks, "should split 3 changes into 3 hunks")
    -- Hunk 1: line 5 change (public partial class ... //hello)
    assert.are.equal(5, hunks[1].start)
    assert.is_not_equal(hunks[1].removed[1], hunks[1].added[1])
    -- Hunk 2: line 10 change (} //hello)
    assert.are.equal(10, hunks[2].start)
    assert.is_not_equal(hunks[2].removed[1], hunks[2].added[1])
    -- Hunk 3: line 14 change (return ... //hello)
    assert.are.equal(14, hunks[3].start)
    assert.is_not_equal(hunks[3].removed[1], hunks[3].added[1])
    -- Each split hunk should have same number of removed/added elements
    for _, h in ipairs(hunks) do
      assert.are.equal(#h.removed, #h.added, "removed and added should be balanced")
      assert.is_not_nil(h.end_line)
    end
  end)
end)
