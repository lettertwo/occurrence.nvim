local assert = require("luassert")
local util = require("tests.util")
local Location = require("occurrence.Location")

describe("Location", function()
  describe(".new", function()
    it("creates a location from line and col", function()
      local loc = Location.new(1, 2)
      assert.is_table(loc)
      assert.equals(1, loc.line)
      assert.equals(2, loc.col)
    end)

    it("errors if line or col is invalid", function()
      assert.error(function()
        Location.new(-1, 0)
      end)
      assert.error(function()
        Location.new(0, -1)
      end)
      assert.error(function()
        Location.new("a", 0)
      end)
      assert.error(function()
        Location.new(0, "b")
      end)
    end)
  end)

  describe("read-only enforcement", function()
    it("errors on assignment", function()
      local loc = Location.new(1, 2)
      assert.error(function()
        loc.line = 3
      end)
      assert.error(function()
        ---@diagnostic disable-next-line: inject-field
        loc.foo = "bar"
      end)
    end)
  end)

  describe("__tostring", function()
    it("returns a string representation", function()
      local loc = Location.new(1, 2)
      assert.equals("Location(1, 2)", tostring(loc))
    end)
  end)

  describe("from_markpos", function()
    it("converts mark-like pos to location", function()
      local loc = assert(Location.from_markpos({ 2, 3 }))
      assert.equals(1, loc.line)
      assert.equals(3, loc.col)
    end)
    it("returns nil for invalid pos", function()
      assert.is_nil(Location.from_markpos({ 0, 3 }))
      assert.is_nil(Location.from_markpos({ 2, -1 }))
    end)
  end)

  describe("from_pos", function()
    it("converts search-like pos to location", function()
      local loc = assert(Location.from_pos({ 1, 2 }))
      assert.equals(0, loc.line)
      assert.equals(1, loc.col)
    end)

    it("converts 3+ element pos arrays correctly", function()
      local loc = assert(Location.from_pos({ 0, 1, 2 }))
      assert.equals(0, loc.line)
      assert.equals(1, loc.col)

      ---@diagnostic disable-next-line: assign-type-mismatch
      local loc2 = assert(Location.from_pos({ 999, 1, 2, "extra" }))
      assert.equals(0, loc2.line)
      assert.equals(1, loc2.col)
    end)

    it("returns nil for invalid pos", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.is_nil(Location.from_pos(nil))
      assert.is_nil(Location.from_pos({}))
      assert.is_nil(Location.from_pos({ 0, 2 }))
      assert.is_nil(Location.from_pos({ 1, -1 }))
    end)
  end)

  describe("from_extmarkpos", function()
    it("converts extmark-like pos to location", function()
      local loc = assert(Location.from_extmarkpos({ 0, 0 }))
      assert.equals(0, loc.line)
      assert.equals(0, loc.col)

      local loc2 = assert(Location.from_extmarkpos({ 5, 10 }))
      assert.equals(5, loc2.line)
      assert.equals(10, loc2.col)
    end)

    it("returns nil for invalid pos", function()
      assert.is_nil(Location.from_extmarkpos({ -1, 0 }))
      assert.is_nil(Location.from_extmarkpos({ 0, -1 }))
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.is_nil(Location.from_extmarkpos(nil))
    end)
  end)

  describe("serialize/deserialize", function()
    it("serializes and deserializes correctly", function()
      local loc = Location.new(5, 10)
      local serialized = loc:serialize()
      assert.equals("5:10", serialized)

      local deserialized = Location.deserialize(serialized)
      assert.equals(5, deserialized.line)
      assert.equals(10, deserialized.col)
    end)

    it("roundtrip preserves equality", function()
      local original = Location.new(0, 0)
      local roundtrip = Location.deserialize(original:serialize())
      assert.is_true(original == roundtrip)

      local original2 = Location.new(100, 50)
      local roundtrip2 = Location.deserialize(original2:serialize())
      assert.is_true(original2 == roundtrip2)
    end)
  end)

  describe("totable", function()
    it("returns a table representation", function()
      local loc = Location.new(3, 7)
      local table_rep = loc:totable()
      assert.same({ 3, 7 }, table_rep)
    end)
  end)

  describe("to_extmarkpos", function()
    it("returns extmark-like position", function()
      local loc = Location.new(5, 10)
      local pos = loc:to_extmarkpos()
      assert.same({ 5, 10 }, pos)
    end)
  end)

  describe("to_pos", function()
    it("returns search-like position", function()
      local loc = Location.new(0, 0)
      local pos = loc:to_pos()
      assert.same({ 1, 1 }, pos)

      local loc2 = Location.new(5, 10)
      local pos2 = loc2:to_pos()
      assert.same({ 6, 11 }, pos2)
    end)
  end)

  describe("to_markpos", function()
    it("returns mark-like position", function()
      local loc = Location.new(0, 0)
      local pos = loc:to_markpos()
      assert.same({ 1, 0 }, pos)

      local loc2 = Location.new(5, 10)
      local pos2 = loc2:to_markpos()
      assert.same({ 6, 10 }, pos2)
    end)
  end)

  describe("distance", function()
    it("calculates distance between locations", function()
      local loc1 = Location.new(0, 0)
      local loc2 = Location.new(3, 4)
      local distance = loc1:distance(loc2)
      assert.equals(5, distance) -- 3-4-5 triangle
    end)

    it("returns 0 for same location", function()
      local loc = Location.new(5, 5)
      assert.equals(0, loc:distance(loc))
    end)
  end)

  describe("add", function()
    it("adds column offset with single argument", function()
      local loc = Location.new(5, 10)
      local new_loc = loc:add(3)
      assert.equals(5, new_loc.line)
      assert.equals(13, new_loc.col)
    end)

    it("adds line and column offset with two arguments", function()
      local loc = Location.new(5, 10)
      local new_loc = loc:add(2, 3)
      assert.equals(7, new_loc.line)
      assert.equals(13, new_loc.col)
    end)

    it("works with negative offsets", function()
      local loc = Location.new(10, 20)
      local new_loc = loc:add(-2, -5)
      assert.equals(8, new_loc.line)
      assert.equals(15, new_loc.col)
    end)

    it("errors with invalid arguments", function()
      local loc = Location.new(0, 0)
      assert.error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        loc:add("invalid")
      end)
    end)
  end)

  describe("__add operator", function()
    it("works with single integer", function()
      local loc = Location.new(5, 10)
      local new_loc = loc + 3
      assert.equals(5, new_loc.line)
      assert.equals(13, new_loc.col)
    end)
  end)

  describe("comparison operators", function()
    it("__eq compares locations for equality", function()
      local loc1 = Location.new(5, 10)
      local loc2 = Location.new(5, 10)
      local loc3 = Location.new(5, 11)

      assert.is_true(loc1 == loc2)
      assert.is_false(loc1 == loc3)
    end)

    it("__lt compares locations", function()
      local loc1 = Location.new(5, 10)
      local loc2 = Location.new(5, 11)
      local loc3 = Location.new(6, 5)

      assert.is_true(loc1 < loc2)
      assert.is_true(loc1 < loc3)
      assert.is_false(loc2 < loc1)
    end)

    it("__le compares locations", function()
      local loc1 = Location.new(5, 10)
      local loc2 = Location.new(5, 10)
      local loc3 = Location.new(5, 11)

      assert.is_true(loc1 <= loc2)
      assert.is_true(loc1 <= loc3)
      assert.is_false(loc3 <= loc1)
    end)

    it("__gt compares locations", function()
      local loc1 = Location.new(5, 11)
      local loc2 = Location.new(5, 10)
      local loc3 = Location.new(6, 5)

      assert.is_true(loc1 > loc2)
      assert.is_true(loc3 > loc1)
      assert.is_false(loc2 > loc1)
    end)

    it("__ge compares locations", function()
      local loc1 = Location.new(5, 10)
      local loc2 = Location.new(5, 10)
      local loc3 = Location.new(5, 9)

      assert.is_true(loc1 >= loc2)
      assert.is_true(loc1 >= loc3)
      assert.is_false(loc3 >= loc1)
    end)

    it("handles line vs column precedence correctly", function()
      local loc1 = Location.new(4, 100)
      local loc2 = Location.new(5, 0)

      assert.is_true(loc1 < loc2)
      assert.is_false(loc1 > loc2)
    end)
  end)

  describe("integration tests", function()
    before_each(function()
      util.buffer({
        "line 0: short",
        "line 1: this is a longer line with more content",
        "line 2: medium length line",
        "line 3: x",
        "", -- empty line 4
      })
    end)

    describe("of_cursor", function()
      it("returns cursor location", function()
        vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- line 1 (1-indexed), col 0
        local loc = assert(Location.of_cursor())
        assert.equals(0, loc.line) -- 0-indexed
        assert.equals(0, loc.col)

        vim.api.nvim_win_set_cursor(0, { 2, 5 }) -- line 2, col 5
        local loc2 = assert(Location.of_cursor())
        assert.equals(1, loc2.line)
        assert.equals(5, loc2.col)
      end)
    end)

    describe("of_mark", function()
      it("returns location of a mark", function()
        -- Set cursor and create a mark
        vim.api.nvim_win_set_cursor(0, { 2, 10 })
        vim.api.nvim_buf_set_mark(0, "a", 2, 10, {})

        local loc = assert(Location.of_mark("a"))
        assert.equals(1, loc.line) -- 0-indexed (vim mark is 1-indexed)
        assert.equals(10, loc.col)
      end)

      it("returns nil for non-existent mark", function()
        local loc = Location.of_mark("z")
        -- Non-existent marks typically return {0, 0} which gets converted to nil
        -- due to the validation in from_markpos
        assert.is_nil(loc)
      end)
    end)

    describe("of_line_start", function()
      it("returns start of specified line", function()
        local loc = Location.of_line_start(1) -- 0-indexed line 1
        assert.equals(1, loc.line)
        assert.equals(0, loc.col)

        local loc2 = Location.of_line_start(3) -- 0-indexed line 3
        assert.equals(3, loc2.line)
        assert.equals(0, loc2.col)
      end)

      it("returns start of current line when no line specified", function()
        vim.api.nvim_win_set_cursor(0, { 3, 15 }) -- line 3, col 15
        local loc = Location.of_line_start()
        assert.equals(2, loc.line) -- cursor line (0-indexed)
        assert.equals(0, loc.col)
      end)
    end)

    describe("of_line_end", function()
      it("returns end of specified line", function()
        local loc = Location.of_line_end(0) -- "line 0: short" = 13 chars
        assert.equals(0, loc.line)
        assert.equals(13, loc.col)

        local loc2 = Location.of_line_end(1) -- longer line
        assert.equals(1, loc2.line)
        assert.equals(47, loc2.col) -- length of "line 1: this is a longer line with more content"
      end)

      it("returns end of current line when no line specified", function()
        vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- line 4 (1-indexed), "line 3: x" = 9 chars
        local loc = Location.of_line_end()
        assert.equals(3, loc.line) -- 0-indexed
        assert.equals(9, loc.col)
      end)

      it("handles empty lines", function()
        local loc = Location.of_line_end(4) -- empty line
        assert.equals(4, loc.line)
        assert.equals(0, loc.col)
      end)

      it("works with cursor movements", function()
        -- Test a sequence of operations
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        local start_loc = assert(Location.of_cursor())

        vim.api.nvim_win_set_cursor(0, { 2, 20 })
        local end_loc = assert(Location.of_cursor())

        assert.is_true(start_loc < end_loc)
        assert.equals(1, end_loc.line - start_loc.line)
        assert.equals(20, end_loc.col)
      end)

      it("line start and end create valid ranges", function()
        local line_start = Location.of_line_start(1)
        local line_end = Location.of_line_end(1)

        assert.is_true(line_start <= line_end)
        assert.equals(1, line_start.line)
        assert.equals(1, line_end.line)
        assert.equals(0, line_start.col)
        assert.is_true(line_end.col > 0) -- line has content
      end)
    end)
  end)
end)

