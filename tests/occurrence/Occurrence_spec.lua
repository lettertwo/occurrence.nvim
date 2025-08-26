local assert = require("luassert")
local util = require("tests.util")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")

local NS = vim.api.nvim_create_namespace("Occurrence")

describe("Occurrence", function()
  describe("matches", function()
    it("finds matches", function()
      local bufnr = util.buffer("foo")

      local foo = Occurrence.new(bufnr, "foo", {})
      assert.is_true(foo:has_matches())

      local bar = Occurrence.new(bufnr, "bar", {})
      assert.is_false(bar:has_matches())
    end)

    it("iterates over matches", function()
      local bufnr = util.buffer("foo bar foo")

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

    it("iterates over matches with a custom range", function()
      local bufnr = util.buffer("foo bar foo")

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
  end)

  describe("marks", function()
    it("marks matches", function()
      local bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      foo:mark()
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)
    end)

    it("marks matches within a range", function()
      local bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      foo:mark(Range.deserialize("0:0::0:4"))
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 1, 0, 0 } }, marks)
    end)

    it("unmarks matches", function()
      local bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      foo:mark()
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:unmark()
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({}, marks)
    end)

    it("unmarks matches within a range", function()
      local bufnr = util.buffer("foo bar foo")
      local foo = Occurrence.new(bufnr, "foo", {})

      foo:mark(Range.deserialize("0:0::1:0"))
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({
        { 1, 0, 0 },
        { 2, 0, 8 },
      }, marks)

      foo:unmark(Range.deserialize("0:0::0:4"))
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 2, 0, 8 } }, marks)
    end)

    it("iterates over marks", function()
      local bufnr = util.buffer("foo bar foo")

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

    it("iterates over marks within a range", function()
      local bufnr = util.buffer("foo bar foo")

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
  end)

  describe("match_cursor", function()
    describe("default", function()
      it("moves the cursor to the nearest occurrence", function()
        local bufnr = util.buffer("foo bar foo")
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
    end)

    describe('direction = "forward"', function()
      it("moves the cursor forward to the nearest occurrence", function()
        local bufnr = util.buffer("foo bar foo")
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
    end)

    describe('direction = "backward"', function()
      it("moves the cursor backward to the nearest occurrence", function()
        local bufnr = util.buffer("foo bar foo")
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
    end)

    describe("wrap = true", function()
      it("wraps the cursor to the nearest occurrence", function()
        local bufnr = util.buffer("foo bar foo")
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
    end)

    describe("marked = true", function()
      it("moves the cursor to marked occurrences", function()
        local bufnr = util.buffer("foo bar foo")
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
    end)
  end)
end)
