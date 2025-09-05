local assert = require("luassert")
local util = require("tests.util")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")

local NS = vim.api.nvim_create_namespace("Occurrence")

describe("Occurrence", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("matches", function()
    it("finds matches", function()
      bufnr = util.buffer("foo")

      local foo = Occurrence.new(bufnr, "foo", {})
      assert.is_true(foo:has_matches())

      local bar = Occurrence.new(bufnr, "bar", {})
      assert.is_false(bar:has_matches())
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

      local foo = Occurrence.new(bufnr, "foo.bar", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, "foo(bar)", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, "foo[bar]", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, "foo{bar}", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, "foo^bar$", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, "foo*bar+", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, "foo?bar|", {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, [[foo\\bar]], {})
      assert.is_true(foo:has_matches())

      foo = Occurrence.new(bufnr, [[foo\\nbar]], {})
      assert.is_true(foo:has_matches())
    end)

    it("is case-sensitive", function()
      bufnr = util.buffer("Foo foo FOO")

      local foo = Occurrence.new(bufnr, "foo", {})
      assert.is_true(foo:has_matches())
      local count = 0
      for _ in foo:matches() do
        count = count + 1
      end
      assert.equals(1, count)
    end)

    it("iterates over matches", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.new(bufnr, "foo", {})
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
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

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

      local foo = Occurrence.new(bufnr, "foo", {})
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
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

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
      local occ = Occurrence.new(bufnr, "bar", {})
      occ:add("baz", {})

      local matches = vim.iter(occ:matches()):map(tostring):totable()
      assert.same({
        "Range(start: Location(0, 12), stop: Location(0, 15))",
        "Range(start: Location(0, 16), stop: Location(0, 19))",
        "Range(start: Location(1, 12), stop: Location(1, 15))",
        "Range(start: Location(1, 16), stop: Location(1, 19))",
      }, matches)
    end)
  end)

  describe("marks", function()
    it("marks matches", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      assert.is_false(foo:has_marks())
      foo:mark()
      assert.is_true(foo:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)
    end)

    it("marks matches for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

      assert.is_false(occ:has_marks())
      occ:mark()
      assert.is_true(occ:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
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
      local foo = Occurrence.new(bufnr, "foo", {})

      assert.is_false(foo:has_marks())
      foo:mark(Range.deserialize("0:0::0:4"))
      assert.is_true(foo:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 1, 0, 0 } }, marks)
    end)

    it("marks matches within a range for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

      assert.is_false(occ:has_marks())
      occ:mark(Range.deserialize("0:0::0:15"))
      assert.is_true(occ:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 4 },
        { 3, 0, 8 },
        { 4, 0, 12 },
      }, marks)
    end)

    it("unmarks matches", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      assert.is_false(foo:has_marks())
      foo:mark()
      assert.is_true(foo:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:unmark()
      assert.is_false(foo:has_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({}, marks)
    end)

    it("unmarks matches for multiple patterns", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

      assert.is_false(occ:has_marks())
      occ:mark()
      assert.is_true(occ:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 4 },
        { 3, 0, 8 },
        { 4, 0, 12 },
        { 5, 0, 16 },
        { 6, 0, 20 },
      }, marks)

      occ:unmark()
      assert.is_false(occ:has_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({}, marks)
    end)

    it("unmarks matches within a range", function()
      bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      assert.is_false(foo:has_marks())
      foo:mark(Range.deserialize("0:0::1:0"))
      assert.is_true(foo:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:unmark(Range.deserialize("0:0::0:4"))
      assert.is_true(foo:has_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 2, 0, 8 } }, marks)
    end)

    it("unmarks matches for multiple patterns within a range", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

      assert.is_false(occ:has_marks())
      occ:mark(Range.deserialize("0:8::1:0"))
      assert.is_true(occ:has_marks())

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 8 },
        { 2, 0, 12 },
        { 3, 0, 16 },
        { 4, 0, 20 },
      }, marks)

      occ:unmark(Range.deserialize("0:0::0:15"))
      assert.is_true(occ:has_marks())

      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 3, 0, 16 },
        { 4, 0, 20 },
      }, marks)
    end)

    it("iterates over marks", function()
      bufnr = util.buffer("foo bar foo")

      local foo = Occurrence.new(bufnr, "foo", {})
      foo:mark(Range.deserialize("0:0::1:0"))

      local marked = {}
      for mark in foo:marks() do
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
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

      occ:mark()

      local marked = {}
      for mark in occ:marks() do
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

      local foo = Occurrence.new(bufnr, "foo", {})
      foo:mark(Range.deserialize("0:0::1:0"))

      local marked = {}
      for mark in foo:marks({ range = Range.deserialize("0:0::0:4") }) do
        table.insert(marked, tostring(mark))
      end

      assert.same({
        "Range(start: Location(0, 0), stop: Location(0, 3))",
      }, marked)
    end)

    it("iterates over marks for multiple patterns within a range", function()
      bufnr = util.buffer("foo bar baz foo bar baz")
      local occ = Occurrence.new(bufnr, "foo", {})
      occ:add("bar", {})
      occ:add("baz", {})

      occ:mark(Range.deserialize("0:0::1:15"))

      local marked = {}
      for mark in occ:marks({ range = Range.deserialize("0:0::0:15") }) do
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
      local occ = Occurrence.new(bufnr, "bar", {})
      occ:add("baz", {})

      occ:mark()

      local marked = {}
      for mark in occ:marks() do
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
      local occ = Occurrence.new(bufnr, [[baz\n        foo]], {})

      assert.is_true(occ:mark())

      local marked = vim.iter(occ:marks()):map(tostring):totable()

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
      local occ = Occurrence.new(bufnr, [[baz\n        foo]], {})
      occ:add([[bar baz\n        foo]], {})

      assert.is_true(occ:mark())

      local marked = vim.iter(occ:marks()):map(tostring):totable()

      assert.same({
        "Range(start: Location(0, 8), stop: Location(1, 11))",
        "Range(start: Location(0, 12), stop: Location(1, 11))",
        "Range(start: Location(1, 12), stop: Location(2, 11))",
        "Range(start: Location(1, 16), stop: Location(2, 11))",
      }, marked)
    end)
  end)

  describe("match_cursor", function()
    describe("default", function()
      it("moves the cursor to the nearest occurrence", function()
        bufnr = util.buffer("foo bar foo")
        -- match "bar"
        local o = Occurrence.new(bufnr, "bar", {})

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor()
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor doesn't wrap if there's not another match
        o:match_cursor()
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves after updating the occurrence to match "foo"
        o:set("foo")
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
        local occ = Occurrence.new(bufnr, "foo", {})
        occ:add("bar", {})

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
        local o = Occurrence.new(bufnr, "bar", {})

        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor doesn't wrap if there's not another match
        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves after updating the occurrence
        o:set("foo")
        o:match_cursor({ direction = "forward" })
        assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("moves the cursor forward to the nearest occurrence for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.new(bufnr, "foo", {})
        occ:add("bar", {})

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
        local o = Occurrence.new(bufnr, "bar", {})

        -- move cursor to the end of the buffer
        vim.cmd("normal! G$")
        assert.same({ 1, 10 }, vim.api.nvim_win_get_cursor(0))

        o:match_cursor({ direction = "backward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor doesn't wrap if there's not another match
        o:match_cursor({ direction = "backward" })
        assert.same({ 1, 4 }, vim.api.nvim_win_get_cursor(0))

        -- test that the cursor moves after updating the occurrence
        o:set("foo")
        o:match_cursor({ direction = "backward" })
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("moves the cursor backward to the nearest occurrence for multiple patterns", function()
        bufnr = util.buffer("foo bar baz foo bar baz")
        local occ = Occurrence.new(bufnr, "foo", {})
        occ:add("bar", {})

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
        local o = Occurrence.new(bufnr, "foo", {})

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
        local occ = Occurrence.new(bufnr, "foo", {})
        occ:add("bar", {})

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
        local o = Occurrence.new(bufnr, "foo", {})

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
        local occ = Occurrence.new(bufnr, "foo", {})
        occ:add("bar", {})

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
      local o = Occurrence.new(bufnr, "bar", {})
      o:add("baz", {})

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
end)
