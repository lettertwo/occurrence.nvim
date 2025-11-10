local assert = require("luassert")
local util = require("tests.util")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

describe("Occurrence", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe(".get", function()
    it("creates new occurrence", function()
      bufnr = util.buffer("foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      assert.is_table(foo)
      assert.equals(bufnr, foo.buffer)
      assert.has_match("foo", foo.patterns[1])
      assert.is_table(foo.extmarks)
    end)

    it("reuses existing occurrence", function()
      bufnr = util.buffer("foo")

      local foo1 = Occurrence.get(bufnr, "foo", "word")
      local foo2 = Occurrence.get(bufnr, "foo", "word")
      assert.equals(foo1, foo2)
    end)

    it("uses existing occurrence for different patterns", function()
      bufnr = util.buffer("foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      local bar = Occurrence.get(bufnr, "bar", "word")
      assert.equals(foo, bar)
      assert.has_match("foo", foo.patterns[1])
      assert.has_match("bar", foo.patterns[2])
    end)

    it("creates new occurrence for different buffers", function()
      bufnr = util.buffer("foo")
      local bufnr2 = util.buffer("foo")

      local foo1 = Occurrence.get(bufnr, "foo", "word")
      local foo2 = Occurrence.get(bufnr2, "foo", "word")
      assert.is_not.equals(foo1, foo2)

      vim.api.nvim_buf_delete(bufnr2, { force = true })
    end)
  end)

  describe(".del", function()
    it("deletes existing occurrence", function()
      bufnr = util.buffer("foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      assert.is_table(foo)

      Occurrence.del(bufnr)
      local foo2 = Occurrence.get(bufnr, "foo", "word")
      assert.is_not.equals(foo, foo2)
    end)

    it("handles non-existing occurrence", function()
      bufnr = util.buffer("foo")

      assert.has_no.errors(function()
        Occurrence.del(bufnr)
      end)
    end)
  end)

  describe(":matches", function()
    it("finds matches", function()
      bufnr = util.buffer("foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      assert.is_true(foo:has_matches())

      local bar = Occurrence.get(bufnr, "bar", "word")
      assert.is_true(bar:has_matches()) -- should still have "foo" matches
    end)

    it("finds matches with special characters", function()
      bufnr = util.buffer([[foo.bar
      foo(bar)
      foo[bar]
      foo{bar}
      foo^bar$
      foo*bar+
      foo?bar|
      foo\bar
      foo\nbar]])

      local foo = Occurrence.get(bufnr, "foo.bar", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, "foo(bar)", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, "foo[bar]", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, "foo{bar}", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, "foo^bar$", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, "foo*bar+", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, "foo?bar|", "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, [[foo\bar]], "selection")
      assert.is_true(foo:has_matches())

      foo = Occurrence.get(bufnr, [[foo\nbar]], "selection")
      assert.is_true(foo:has_matches())
    end)

    it("is case-sensitive", function()
      bufnr = util.buffer("Foo foo FOO")

      local foo = Occurrence.get(bufnr, "foo", "word")
      assert.is_true(foo:has_matches())
      local count = 0
      for _ in foo:matches() do
        count = count + 1
      end
      assert.equals(1, count)
    end)

    it("iterates over matches", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      local matches = {}
      for match in foo:matches() do
        table.insert(matches, tostring(match))
      end

      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
      }, matches)
    end)

    it("iterates over matches for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      local matches = {}
      for match in occ:matches() do
        table.insert(matches, tostring(match))
      end
      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 4), stop: Location(0, 7))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
        "Range(start: Location(0, 12), stop: Location(0, 15))",
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(0, 20), stop: Location(0, 23))",
      }, matches)
    end)

    it("iterates over matches with a custom range", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      local matches = {}
      for match in foo:matches(Range.deserialize("0:0::0:4")) do
        table.insert(matches, tostring(match))
      end

      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
      }, matches)

      matches = {}
      for match in foo:matches(Range.deserialize("0:4::1:0")) do
        table.insert(matches, tostring(match))
      end

      assert.same({
        "Range(start: Location(0, 8), stop: Location(0, 11))",
      }, matches)
    end)

    it("iterates over matches for multiple patterns with a custom range", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      local matches = {}
      for match in occ:matches(Range.deserialize("0:0::0:15")) do
        table.insert(matches, tostring(match))
      end
      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 4), stop: Location(0, 7))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
        "Range(start: Location(0, 12), stop: Location(0, 15))",
      }, matches)

      matches = {}
      for match in occ:matches(Range.deserialize("0:16::1:0")) do
        table.insert(matches, tostring(match))
      end
      assert.same({
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(0, 20), stop: Location(0, 23))",
      }, matches)
    end)

    it("iterates over matches for multiple patterns on multiple lines", function()
      bufnr = util.buffer([[
        foo bar baz
        foo bar baz
      ]])
      local occ = Occurrence.get(bufnr, "bar", "word")
      occ:add_pattern("baz", "word")

      local matches = vim.iter(occ:matches()):map(tostring):totable()
      assert.same({
        "Range(start: Location(0, 12), stop: Location(0, 15))",
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(1, 12), stop: Location(1, 15))",
        "Range(start: Location(1, 16), stop: Location(1, 19))",
      }, matches)
    end)

    it("iterates over matches for a provided pattern", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      local matches = {}
      for match in foo:matches(nil, "bar") do
        table.insert(matches, tostring(match))
      end

      assert.same({
        "Range(start: Location(0, 4), stop: Location(0, 7))",
      }, matches)
    end)

    it("iterates over matches for a provided pattern with a custom range", function()
      bufnr = util.buffer("foo bar foo baz foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      local matches = {}
      for match in foo:matches(Range.deserialize("0:0::0:15"), "foo") do
        table.insert(matches, tostring(match))
      end

      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
      }, matches)
    end)

    it("iterates over matches for a provided pattern on multiple lines", function()
      bufnr = util.buffer([[
        foo bar baz
        foo bar baz
        foo bar baz
      ]])
      local occ = Occurrence.get(bufnr, "bar", "word")
      occ:add_pattern("baz", "word")

      local matches = vim.iter(occ:matches(nil, "baz")):map(tostring):totable()
      assert.same({
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(1, 16), stop: Location(1, 19))",
        "Range(start: Location(2, 16), stop: Location(2, 19))",
      }, matches)
    end)

    it("iterates over multiple provided patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      local matches = {}
      for match in occ:matches(nil, { "foo", "baz" }) do
        table.insert(matches, tostring(match))
      end
      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
        "Range(start: Location(0, 12), stop: Location(0, 15))",
        "Range(start: Location(0, 20), stop: Location(0, 23))",
      }, matches)
    end)

    it("iterates over multiple provided patterns with a custom range", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      local matches = {}
      for match in occ:matches(Range.deserialize("0:5::0:15"), { "foo", "baz" }) do
        table.insert(matches, tostring(match))
      end
      assert.same({
        "Range(start: Location(0, 8), stop: Location(0, 11))",
        "Range(start: Location(0, 12), stop: Location(0, 15))",
      }, matches)
    end)

    it("deduplicates identical matches from multiple patterns", function()
      bufnr = util.buffer("foo foo foo")
      local occ = Occurrence.get(bufnr)
      occ:add_pattern([[fo*]], "pattern")
      occ:add_pattern("foo", "selection")
      occ:add_pattern("foo", "word")

      local matches = vim.iter(occ:matches()):map(tostring):totable()
      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 4), stop: Location(0, 7))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
      }, matches) -- only three unique matches
    end)
  end)

  describe(":marks", function()
    it("marks matches", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.get(bufnr, "foo", "word")

      assert.is_false(foo.extmarks:has_any_marks())
      foo:mark()
      assert.is_true(foo.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)
    end)

    it("marks matches for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      assert.is_false(occ.extmarks:has_any_marks())
      occ:mark()
      assert.is_true(occ.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 4 },
        { 3, 0, 8 },
        { 4, 0, 12 },
        { 5, 0, 16 },
        { 6, 0, 20 },
      }, marks)
    end)

    it("marks matches within a range", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.get(bufnr, "foo", "word")

      assert.is_false(foo.extmarks:has_any_marks())
      foo:mark(Range.deserialize("0:0::0:4"))
      assert.is_true(foo.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({ { 1, 0, 0 } }, marks)
    end)

    it("marks matches within a range for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      assert.is_false(occ.extmarks:has_any_marks())
      occ:mark(Range.deserialize("0:0::0:15"))
      assert.is_true(occ.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 4 },
        { 3, 0, 8 },
        { 4, 0, 12 },
      }, marks)
    end)

    it("unmarks matches", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.get(bufnr, "foo", "word")

      assert.is_false(foo.extmarks:has_any_marks())
      foo:mark()
      assert.is_true(foo.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:unmark()
      assert.is_false(foo.extmarks:has_any_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks)
    end)

    it("unmarks matches for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      assert.is_false(occ.extmarks:has_any_marks())
      occ:mark()
      assert.is_true(occ.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 4 },
        { 3, 0, 8 },
        { 4, 0, 12 },
        { 5, 0, 16 },
        { 6, 0, 20 },
      }, marks)

      occ:unmark()
      assert.is_false(occ.extmarks:has_any_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks)
    end)

    it("unmarks matches within a range", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.get(bufnr, "foo", "word")

      assert.is_false(foo.extmarks:has_any_marks())
      foo:mark(Range.deserialize("0:0::1:0"))
      assert.is_true(foo.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:unmark(Range.deserialize("0:0::0:4"))
      assert.is_true(foo.extmarks:has_any_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({ { 2, 0, 8 } }, marks)
    end)

    it("unmarks matches for multiple patterns within a range", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      assert.is_false(occ.extmarks:has_any_marks())
      occ:mark(Range.deserialize("0:8::1:0"))
      assert.is_true(occ.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 8 },
        { 2, 0, 12 },
        { 3, 0, 16 },
        { 4, 0, 20 },
      }, marks)

      occ:unmark(Range.deserialize("0:0::0:15"))
      assert.is_true(occ.extmarks:has_any_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 3, 0, 16 },
        { 4, 0, 20 },
      }, marks)
    end)

    it("iterates over marks", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      foo:mark(Range.deserialize("0:0::1:0"))

      local marked = {}
      for _, mark in foo.extmarks:iter() do
        table.insert(marked, tostring(mark))
      end

      assert.equal(#marked, 2)

      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
      }, marked)
    end)

    it("iterates over marks for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      occ:mark()

      local marked = {}
      for _, mark in occ.extmarks:iter() do
        table.insert(marked, tostring(mark))
      end
      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 4), stop: Location(0, 7))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
        "Range(start: Location(0, 12), stop: Location(0, 15))",
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(0, 20), stop: Location(0, 23))",
      }, marked)
    end)

    it("iterates over marks within a range", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.get(bufnr, "foo", "word")
      foo:mark(Range.deserialize("0:0::1:0"))

      local marked = {}
      for _, mark in foo.extmarks:iter(Range.deserialize("0:0::0:4")) do
        table.insert(marked, tostring(mark))
      end

      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
      }, marked)
    end)

    it("iterates over marks for multiple patterns within a range", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      occ:mark(Range.deserialize("0:0::1:15"))

      local marked = {}
      for _, mark in occ.extmarks:iter(Range.deserialize("0:0::0:15")) do
        table.insert(marked, tostring(mark))
      end
      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
        "Range(start: Location(0, 4), stop: Location(0, 7))",
        "Range(start: Location(0, 8), stop: Location(0, 11))",
        "Range(start: Location(0, 12), stop: Location(0, 15))",
      }, marked)
    end)

    it("iterates over marks for multiple patterns on multiple lines", function()
      bufnr = util.buffer([[
        foo bar baz
        foo bar baz
      ]])
      local occ = Occurrence.get(bufnr, "bar", "word")
      occ:add_pattern("baz", "word")

      occ:mark()

      local marked = {}
      for _, mark in occ.extmarks:iter() do
        table.insert(marked, tostring(mark))
      end
      assert.same({
        "Range(start: Location(0, 12), stop: Location(0, 15))",
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(1, 12), stop: Location(1, 15))",
        "Range(start: Location(1, 16), stop: Location(1, 19))",
      }, marked)
    end)

    it("iterates over marks within a multiline pattern", function()
      bufnr = util.buffer([[
        bar baz
        foo bar baz
        foo bar baz
      ]])
      local occ = Occurrence.get(bufnr, [[baz\n        foo]], "pattern")

      assert.is_true(occ:mark())

      local marked = vim
        .iter(occ.extmarks:iter())
        :map(function(_, r)
          return tostring(r)
        end)
        :totable()

      assert.same({
        "Range(start: Location(0, 12), stop: Location(1, 11))",
        "Range(start: Location(1, 16), stop: Location(2, 11))",
      }, marked)
    end)

    it("iterates over marks for multiple multiline patterns", function()
      bufnr = util.buffer([[
        bar baz
        foo bar baz
        foo bar baz
      ]])
      local occ = Occurrence.get(bufnr, [[baz\n        foo]], "pattern")
      occ:add_pattern([[bar baz\n        foo]], "pattern")

      assert.is_true(occ:mark())

      local marked = vim
        .iter(occ.extmarks:iter())
        :map(function(_, r)
          return tostring(r)
        end)
        :totable()

      assert.same({
        "Range(start: Location(0, 8), stop: Location(1, 11))",
        "Range(start: Location(0, 12), stop: Location(1, 11))",
        "Range(start: Location(1, 12), stop: Location(2, 11))",
        "Range(start: Location(1, 16), stop: Location(2, 11))",
      }, marked)
    end)
  end)

  describe(":match_cursor", function()
    describe("default", function()
      it("moves the cursor to the nearest occurrence", function()
        bufnr = util.buffer("foo bar foo")
        -- match "bar"
        local o = Occurrence.get(bufnr, "bar", "word")

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor()
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor doesn't wrap if there's not another match
        o:match_cursor()
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves after updating the occurrence to match "foo"
        o:clear()
        o:add_pattern("foo", "word")
        o:match_cursor()
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor stays at the nearest occurrence
        o:match_cursor()
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves forward if that is the nearest occurrence
        vim.api.nvim_win_set_cursor(0, { 1, 6 })
        o:match_cursor()
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves backward if that is the nearest occurrence
        vim.api.nvim_win_set_cursor(0, { 1, 3 })
        o:match_cursor()
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("moves the cursor to the nearest occurrence for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.get(bufnr, "foo", "word")
        occ:add_pattern("bar", "word")

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor stays at the nearest occurrence
        occ:match_cursor()
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor()
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves backward if that is the nearest occurrence
        vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- somewhere just past 'bar'
        occ:match_cursor()
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        -- test that the cursor moves forward if that is the nearest occurrence
        vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- somewhere just before next 'foo'
        occ:match_cursor()
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'foo'
      end)
    end)

    describe('direction = "forward"', function()
      it("moves the cursor forward to the nearest occurrence", function()
        bufnr = util.buffer("foo bar foo")
        local o = Occurrence.get(bufnr, "bar", "word")

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor doesn't wrap if there's not another match
        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves after updating the occurrence
        o:clear()
        o:add_pattern("foo", "word")
        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("moves the cursor forward to the nearest occurrence for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.get(bufnr, "foo", "word")
        occ:add_pattern("bar", "word")

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'foo'

        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        -- test that the cursor doesn't move if there's not another match
        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    describe('direction = "backward"', function()
      it("moves the cursor backward to the nearest occurrence", function()
        bufnr = util.buffer("foo bar foo")
        local o = Occurrence.get(bufnr, "bar", "word")

        -- move cursor to the end of the buffer
        vim.cmd("normal! G$")
        assert.same({ 1, 10 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor({ direction = "backward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor doesn't wrap if there's not another match
        o:match_cursor({ direction = "backward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves after updating the occurrence
        o:clear()
        o:add_pattern("foo", "word")
        o:match_cursor({ direction = "backward" })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("moves the cursor backward to the nearest occurrence for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.get(bufnr, "foo", "word")
        occ:add_pattern("bar", "word")

        -- move cursor to the end of the buffer
        vim.cmd("normal! G$")
        assert.same({ 1, 22 }, vim.api.nvim_win_get_cursor(0))

        occ:match_cursor({ direction = "backward" })
        assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        occ:match_cursor({ direction = "backward" })
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'foo'

        occ:match_cursor({ direction = "backward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        occ:match_cursor({ direction = "backward" })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        -- test that the cursor doesn't move if there's not another match
        occ:match_cursor({ direction = "backward" })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    describe("wrap = true", function()
      it("wraps the cursor to the nearest occurrence", function()
        bufnr = util.buffer("foo bar foo")
        local o = Occurrence.get(bufnr, "foo", "word")

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor({ direction = "forward", wrap = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that it wraps backward, too
        o:match_cursor({ direction = "backward", wrap = true })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("wraps the cursor to the nearest occurrence for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.get(bufnr, "foo", "word")
        occ:add_pattern("bar", "word")

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'foo'

        occ:match_cursor({ direction = "forward" })
        assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0)) -- nearest 'bar'

        occ:match_cursor({ direction = "forward", wrap = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0)) -- wrapped to 'foo'

        -- test that it wraps backward, too
        occ:match_cursor({ direction = "backward", wrap = true })
        assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0)) -- wrapped to 'bar'
      end)
    end)

    describe("marked = true", function()
      it("moves the cursor to marked occurrences", function()
        bufnr = util.buffer("foo bar foo")
        local o = Occurrence.get(bufnr, "foo", "word")

        -- mark the first 'foo' match
        assert.is_true(o:mark(Range.deserialize("0:0::0:3")))

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor did not move to the unmarked match
        o:match_cursor({ direction = "forward", marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        o:match_cursor({ direction = "forward", wrap = true, marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        o:match_cursor({ direction = "backward", marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        o:match_cursor({ direction = "backward", wrap = true, marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- mark all 'foo' matches
        assert.is_true(o:mark(Range.deserialize("0:0::1:0")))

        -- test that the cursor moves to the next marked match
        o:match_cursor({ direction = "forward", marked = true })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
        o:match_cursor({ direction = "forward", wrap = true, marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        o:match_cursor({ direction = "backward", wrap = true, marked = true })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
        o:match_cursor({ direction = "backward", marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- unmark the first 'foo' match
        assert.is_true(o:unmark(Range.deserialize("0:0::0:3")))

        -- test that the cursor moves to the remaining marked match
        o:match_cursor({ direction = "forward", marked = true })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        o:match_cursor({ direction = "backward", wrap = true, marked = true })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("moves the cursor to marked occurrences for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.get(bufnr, "foo", "word")
        occ:add_pattern("bar", "word")

        -- mark the first 'foo' match
        assert.is_true(occ:mark(Range.deserialize("0:0::0:3")))

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor did not move to the unmarked match
        occ:match_cursor({ direction = "forward", marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor({ direction = "forward", wrap = true, marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor({ direction = "backward", marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor({ direction = "backward", wrap = true, marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- mark the first 'bar' match
        assert.is_true(occ:mark(Range.deserialize("0:4::0:7")))

        -- test that the cursor moves to the next marked match
        occ:match_cursor({ direction = "forward", marked = true })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor({ direction = "forward", wrap = true, marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor({ direction = "backward", wrap = true, marked = true })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))
        occ:match_cursor({ direction = "backward", marked = true })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it("moves the cursor to the nearest occurrence on the same line", function()
      bufnr = util.buffer([[
        foo bar baz
        foo bar baz
      ]])
      local o = Occurrence.get(bufnr, "bar", "word")
      o:add_pattern("baz", "word")

      assert.is_true(o:mark())

      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

      o:match_cursor({ direction = "forward", wrap = true, marked = true })
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0)) -- first 'bar'

      o:match_cursor({ direction = "forward", wrap = true, marked = true })
      assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0)) -- first 'baz'

      o:match_cursor({ direction = "forward", wrap = true, marked = true })
      assert.same({ 2, 12 }, vim.api.nvim_win_get_cursor(0)) -- second 'bar'

      o:match_cursor({ direction = "forward", wrap = true, marked = true })
      assert.same({ 2, 16 }, vim.api.nvim_win_get_cursor(0)) -- second 'baz'

      o:match_cursor({ direction = "backward", wrap = true, marked = true })
      assert.same({ 2, 12 }, vim.api.nvim_win_get_cursor(0)) -- second 'bar'

      o:match_cursor({ direction = "backward", wrap = true, marked = true })
      assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0)) -- first 'baz'

      o:match_cursor({ direction = "backward", wrap = true, marked = true })
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0)) -- first 'bar'
    end)
  end)

  describe(":add_pattern", function()
    describe("'word' type", function()
      it("matches whole words only", function()
        bufnr = util.buffer("foo foobar barfoo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "word")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
        }, matches) -- only matches "foo", not "foobar" or "barfoo"
      end)

      it("respects word boundaries with special chars", function()
        bufnr = util.buffer("foo foo.bar foo-baz")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "word")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 12), stop: Location(0, 15))",
        }, matches) -- all three are whole words
      end)

      it("does not match partial words", function()
        bufnr = util.buffer("testing test retest")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("test", "word")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 8), stop: Location(0, 12))",
        }, matches) -- only "test", not "testing" or "retest"
      end)

      it("matches special characters as whole words", function()
        bufnr = util.buffer([[foo.bar foo.bar.baz]])
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo.bar", "word")

        assert.is_true(occ:has_matches())
        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.equals(2, #matches)
      end)

      it("does not add the same pattern multiple times", function()
        bufnr = util.buffer("foo foo foo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "word")
        occ:add_pattern("foo", "word") -- duplicate
        assert.equal(1, #occ.patterns, "Pattern was added twice")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 8), stop: Location(0, 11))",
        }, matches) -- only three matches, not six
      end)
    end)

    describe("'selection' type", function()
      it("matches literal text without word boundaries", function()
        bufnr = util.buffer("foo foobar barfoo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 14), stop: Location(0, 17))",
        }, matches) -- matches all occurrences including substrings
      end)

      it("matches special regex chars literally", function()
        bufnr = util.buffer("foo.* foo.* test")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo.*", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 5))",
          "Range(start: Location(0, 6), stop: Location(0, 11))",
        }, matches) -- matches literal "foo.*", not as regex
      end)

      it("is case-sensitive", function()
        bufnr = util.buffer("Foo foo FOO")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 4), stop: Location(0, 7))",
        }, matches) -- only lowercase "foo"
      end)

      it("matches regex metacharacters literally", function()
        bufnr = util.buffer([[foo[bar] foo[bar] test]])
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo[bar]", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 8))",
          "Range(start: Location(0, 9), stop: Location(0, 17))",
        }, matches) -- matches literal brackets, not character class
      end)

      it("matches parentheses literally", function()
        bufnr = util.buffer("foo(bar) test foo(bar)")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo(bar)", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 8))",
          "Range(start: Location(0, 14), stop: Location(0, 22))",
        }, matches)
      end)

      it("matches partial words", function()
        bufnr = util.buffer("testing test retest")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("test", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 4))",
          "Range(start: Location(0, 8), stop: Location(0, 12))",
          "Range(start: Location(0, 15), stop: Location(0, 19))",
        }, matches) -- matches all occurrences
      end)

      it("handles multiline selections", function()
        bufnr = util.buffer({ "foo", "bar", "foo", "bar" })
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo\nbar", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(1, 3))",
          "Range(start: Location(2, 0), stop: Location(3, 3))",
        }, matches)
      end)

      it("does not add the same pattern multiple times", function()
        bufnr = util.buffer("foo foo foo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "selection")
        occ:add_pattern("foo", "selection") -- duplicate
        assert.equal(1, #occ.patterns, "Pattern was added twice")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 8), stop: Location(0, 11))",
        }, matches) -- only three matches, not six
      end)
    end)

    describe("'pattern' type", function()
      it("uses raw vim regex", function()
        bufnr = util.buffer("foo foobar barfoo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 14), stop: Location(0, 17))",
        }, matches) -- raw pattern matches all
      end)

      it("supports word boundaries when explicit", function()
        bufnr = util.buffer("foo foobar barfoo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern([[\<foo\>]], "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
        }, matches) -- only whole word "foo"
      end)

      it("supports character classes", function()
        bufnr = util.buffer("foo fao fbo fco")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern([[f[ao]o]], "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
        }, matches) -- matches "foo" and "fao"
      end)

      it("supports alternation", function()
        bufnr = util.buffer("foo bar baz test")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern([[foo\|bar]], "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
        }, matches) -- matches "foo" or "bar"
      end)

      it("supports quantifiers", function()
        bufnr = util.buffer("fo foo fooo test")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern([[foo*]], "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 2))",
          "Range(start: Location(0, 3), stop: Location(0, 6))",
          "Range(start: Location(0, 7), stop: Location(0, 11))",
        }, matches) -- matches "fo", "foo", "fooo"
      end)

      it("supports anchors", function()
        bufnr = util.buffer({ "foo bar", "bar foo" })
        local occ = Occurrence.get(bufnr)
        occ:add_pattern([[^foo]], "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
        }, matches) -- only "foo" at start of line
      end)

      it("does not add the same pattern multiple times", function()
        bufnr = util.buffer("fo foo fooo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern([[fo*]], "pattern")
        occ:add_pattern([[fo*]], "pattern") -- duplicate
        assert.equal(1, #occ.patterns, "Pattern was added twice")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 2))",
          "Range(start: Location(0, 3), stop: Location(0, 6))",
          "Range(start: Location(0, 7), stop: Location(0, 11))",
        }, matches) -- only three matches, not six
      end)
    end)

    describe("mixed pattern types", function()
      it("supports multiple patterns with different types", function()
        bufnr = util.buffer("foo foobar test.* test.*")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("foo", "word")
        occ:add_pattern("test.*", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 11), stop: Location(0, 17))",
          "Range(start: Location(0, 18), stop: Location(0, 24))",
        }, matches) -- 1 whole "foo" + 2 literal "test.*"
      end)

      it("allows word and selection types together", function()
        bufnr = util.buffer("testing test retest")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("test", "word")
        occ:add_pattern("ing", "selection")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 8), stop: Location(0, 12))",
        }, matches) -- "ing" from "testing" + whole word "test"
      end)

      it("allows pattern and word types together", function()
        bufnr = util.buffer("bar foobar fo fooo")
        local occ = Occurrence.get(bufnr)
        occ:add_pattern("bar", "word")
        occ:add_pattern([[fo*]], "pattern")

        local matches = vim.iter(occ:matches()):map(tostring):totable()
        assert.same({
          "Range(start: Location(0, 0), stop: Location(0, 3))",
          "Range(start: Location(0, 4), stop: Location(0, 7))",
          "Range(start: Location(0, 11), stop: Location(0, 13))",
          "Range(start: Location(0, 14), stop: Location(0, 18))",
        }, matches) -- "bar" + "fo" + "foo" + "fooo"
      end)
    end)
  end)

  describe(":clear", function()
    it("clears the occurrence", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.get(bufnr, "foo", "word")

      assert.is_false(foo.extmarks:has_any_marks())
      foo:mark()
      assert.is_true(foo.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:clear()
      assert.is_false(foo.extmarks:has_any_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks)

      local matches = vim.iter(foo:matches()):map(tostring):totable()
      assert.same({}, matches)
    end)

    it("clears the occurrence for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.get(bufnr, "foo", "word")
      occ:add_pattern("bar", "word")
      occ:add_pattern("baz", "word")

      assert.is_false(occ.extmarks:has_any_marks())
      occ:mark()
      assert.is_true(occ.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 4 },
        { 3, 0, 8 },
        { 4, 0, 12 },
        { 5, 0, 16 },
        { 6, 0, 20 },
      }, marks)

      occ:clear()
      occ:add_pattern("bar", "word")
      assert.is_false(occ.extmarks:has_any_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks)

      local matches = vim.iter(occ:matches()):map(tostring):totable()
      assert.same({
        "Range(start: Location(0, 4), stop: Location(0, 7))",
        "Range(start: Location(0, 16), stop: Location(0, 19))",
      }, matches)
    end)
  end)

  describe(":dispose", function()
    it("disposes the occurrence", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.get(bufnr, "foo", "word")

      assert.is_false(foo.extmarks:has_any_marks())
      foo:mark()
      assert.is_true(foo.extmarks:has_any_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:dispose()
      assert.is_false(foo.extmarks:has_any_marks())
      assert.is_true(foo:is_disposed())
      assert.is_true(foo.extmarks:is_disposed())
      assert.is_true(foo.keymap:is_disposed())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks)

      assert.has.error(function()
        foo:add_pattern("foo", "word")
      end, "Cannot use a disposed Occurrence")

      assert.has.error(function()
        foo:mark()
      end, "Cannot use a disposed Occurrence")

      assert.has.error(function()
        foo:unmark()
      end, "Cannot use a disposed Occurrence")

      assert.has.error(function()
        foo:clear()
      end, "Cannot use a disposed Occurrence")
    end)
  end)
end)
