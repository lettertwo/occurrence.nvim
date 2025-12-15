local assert = require("luassert")
local util = require("tests.util")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")
local feedkeys = require("occurrence.feedkeys")

describe("Range", function()
  describe(".new", function()
    it("creates a range from two locations", function()
      local start = Location.new(0, 0)
      local stop = Location.new(0, 5)
      local range = Range.new(start, stop)
      assert.is_table(range)
      assert.same(start, range.start)
      assert.same(stop, range.stop)
    end)

    it("errors if start or stop is not a Location", function()
      local loc = Location.new(0, 0)
      assert.error(function()
        ---@diagnostic disable-next-line: missing-fields
        Range.new({}, loc)
      end)
      assert.error(function()
        ---@diagnostic disable-next-line: missing-fields
        Range.new(loc, {})
      end)
    end)

    it("errors if start > stop", function()
      local start = Location.new(1, 0)
      local stop = Location.new(0, 5)
      assert.error(function()
        Range.new(start, stop)
      end)
    end)

    it("handles zero-width ranges", function()
      local range = Range.new(Location.new(5, 10), Location.new(5, 10))
      assert.equals(5, range.start.line)
      assert.equals(10, range.start.col)
      assert.equals(5, range.stop.line)
      assert.equals(10, range.stop.col)

      -- Zero-width range should not contain any location (end-exclusive)
      assert.is_false(range:contains(Location.new(5, 10)))
      assert.is_false(range:contains(Location.new(5, 11)))
      assert.is_false(range:contains(Location.new(5, 9)))
    end)
  end)

  describe("read-only enforcement", function()
    it("errors on assignment", function()
      local start = Location.new(0, 0)
      local stop = Location.new(0, 5)
      local range = Range.new(start, stop)
      assert.error(function()
        range.start = Location.new(1, 1)
      end)
      assert.error(function()
        ---@diagnostic disable-next-line: inject-field
        range.foo = "bar"
      end)
    end)
  end)

  describe("__tostring", function()
    it("returns a string representation", function()
      local start = Location.new(0, 0)
      local stop = Location.new(0, 5)
      local range = Range.new(start, stop)
      assert.equals("Range(start: Location(0, 0), stop: Location(0, 5), type: char)", tostring(range))
    end)
  end)

  describe("__eq", function()
    it("compares ranges for equality", function()
      local start = Location.new(0, 0)
      local stop = Location.new(0, 5)
      local r1 = Range.new(start, stop)
      local r2 = Range.new(start, stop)
      assert.is_true(r1 == r2)
      local r3 = Range.new(Location.new(0, 1), stop)
      assert.is_false(r1 == r3)
    end)
  end)

  describe("serialize/deserialize", function()
    it("serializes and deserializes correctly", function()
      local start = Location.new(5, 10)
      local stop = Location.new(7, 15)
      local range = Range.new(start, stop)
      local serialized = range:serialize()
      assert.equals("5:10::7:15::char", serialized)

      local deserialized = Range.deserialize(serialized)
      assert.equals(5, deserialized.start.line)
      assert.equals(10, deserialized.start.col)
      assert.equals(7, deserialized.stop.line)
      assert.equals(15, deserialized.stop.col)
    end)

    it("roundtrip preserves equality", function()
      local original = Range.new(Location.new(0, 0), Location.new(2, 10))
      local roundtrip = Range.deserialize(original:serialize())
      assert.is_true(original == roundtrip)

      local original2 = Range.new(Location.new(100, 50), Location.new(100, 75))
      local roundtrip2 = Range.deserialize(original2:serialize())
      assert.is_true(original2 == roundtrip2)
    end)

    it("deserializes as 'char' without explicit type", function()
      local serialized = "3:5::6:10"
      local range = Range.deserialize(serialized)
      assert.equals(3, range.start.line)
      assert.equals(5, range.start.col)
      assert.equals(6, range.stop.line)
      assert.equals(10, range.stop.col)
      assert.equals("char", range.type)
    end)
  end)

  describe("totable", function()
    it("returns a table representation", function()
      local range = Range.new(Location.new(3, 7), Location.new(5, 12))
      local table_rep = range:totable()
      assert.same({ 3, 7, 5, 12 }, table_rep)
    end)
  end)

  describe("move", function()
    it("transposes range to new starting location", function()
      local original = Range.new(Location.new(5, 10), Location.new(7, 15))
      local new_start = Location.new(0, 0)
      local moved = original:move(new_start)

      assert.equals(0, moved.start.line)
      assert.equals(0, moved.start.col)
      assert.equals(2, moved.stop.line) -- 7 - 5 = 2 line difference
      assert.equals(5, moved.stop.col) -- 15 - 10 = 5 col difference
    end)

    it("handles negative offsets correctly", function()
      local original = Range.new(Location.new(10, 20), Location.new(12, 25))
      local new_start = Location.new(5, 15)
      local moved = original:move(new_start)

      assert.equals(5, moved.start.line)
      assert.equals(15, moved.start.col)
      assert.equals(7, moved.stop.line) -- 12 - 10 + 5 = 7
      assert.equals(20, moved.stop.col) -- 25 - 20 + 15 = 20
    end)

    it("preserves range width", function()
      local original = Range.new(Location.new(10, 5), Location.new(10, 15))
      local moved = original:move(Location.new(20, 10))

      -- Width should be preserved (both ranges span 10 columns)
      local orig_width = original.stop.col - original.start.col
      local moved_width = moved.stop.col - moved.start.col
      assert.equals(orig_width, moved_width)
    end)
  end)

  describe("contains", function()
    describe("with Location argument", function()
      it("returns true for location within char range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local loc = Location.new(6, 15)
        assert.is_true(range:contains(loc))
      end)

      it("returns true for location at start (inclusive)", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local loc = Location.new(5, 10)
        assert.is_true(range:contains(loc))
      end)

      it("returns false for location at stop (exclusive)", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local loc = Location.new(8, 20)
        assert.is_false(range:contains(loc))
      end)

      it("returns false for location before range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local loc = Location.new(3, 5)
        assert.is_false(range:contains(loc))
      end)

      it("returns false for location after range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local loc = Location.new(10, 25)
        assert.is_false(range:contains(loc))
      end)

      it("returns true for location within line range", function()
        local line_range = Range.new(Location.new(5, 0), Location.new(8, 30), "line")
        local loc = Location.new(6, 15)
        assert.is_true(line_range:contains(loc))
      end)

      it("returns false for location outside line range", function()
        local line_range = Range.new(Location.new(5, 0), Location.new(8, 30), "line")
        local loc = Location.new(9, 1)
        assert.is_false(line_range:contains(loc))
      end)

      it("returns true for location within block range", function()
        local block_range = Range.new(Location.new(5, 5), Location.new(8, 25), "block")
        local loc = Location.new(6, 15)
        assert.is_true(block_range:contains(loc))
      end)

      it("returns true for location at start of block range (inclusive)", function()
        local block_range = Range.new(Location.new(5, 5), Location.new(8, 25), "block")
        local loc = Location.new(5, 5)
        assert.is_true(block_range:contains(loc))
      end)

      it("returns false for location outside block range", function()
        local block_range = Range.new(Location.new(5, 5), Location.new(8, 25), "block")
        local loc = Location.new(4, 10)
        assert.is_false(block_range:contains(loc))
      end)

      it("returns fals for location at stop of block range (exclusive)", function()
        local block_range = Range.new(Location.new(5, 5), Location.new(8, 25), "block")
        local loc = Location.new(8, 25)
        assert.is_false(block_range:contains(loc))
      end)
    end)

    describe("with Range argument", function()
      it("returns true for same range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local same = Range.new(Location.new(5, 10), Location.new(8, 20))
        assert.is_true(range:contains(same))
      end)

      it("returns true for char range containing char range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local inner = Range.new(Location.new(6, 12), Location.new(7, 18))
        assert.is_true(range:contains(inner))
      end)

      it("returns false for char range extending before", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local extending = Range.new(Location.new(3, 5), Location.new(6, 15))
        assert.is_false(range:contains(extending))
      end)

      it("returns false for char range extending after", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local extending = Range.new(Location.new(6, 15), Location.new(10, 25))
        assert.is_false(range:contains(extending))
      end)

      it("returns true for line range containing char range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local line_range = Range.new(Location.new(4, 0), Location.new(9, 1), "line")
        assert.is_true(line_range:contains(range))
      end)

      it("returns false for line range not containing char range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local line_range = Range.new(Location.new(5, 0), Location.new(8, 10), "line")
        assert.is_false(line_range:contains(range))
      end)

      it("returns true for line range containing a block range", function()
        local line_range = Range.new(Location.new(5, 0), Location.new(8, 30), "line")
        local block_range = Range.new(Location.new(6, 5), Location.new(7, 25), "block")
        assert.is_true(line_range:contains(block_range))
      end)

      it("returns false for line range not containing a block range", function()
        local line_range = Range.new(Location.new(5, 0), Location.new(8, 30), "line")
        local block_range = Range.new(Location.new(4, 5), Location.new(9, 25), "block")
        assert.is_false(line_range:contains(block_range))
      end)

      it("returns true for block range containing char range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local block_range = Range.new(Location.new(4, 5), Location.new(9, 25), "block")
        assert.is_true(block_range:contains(range))
      end)

      it("returns false for block range not containing char range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local block_range = Range.new(Location.new(6, 5), Location.new(9, 25), "block")
        assert.is_false(block_range:contains(range))
      end)

      it("returns true for block range containing a line range", function()
        local line_range = Range.new(Location.new(6, 0), Location.new(7, 30), "line")
        local block_range = Range.new(Location.new(5, 5), Location.new(8, 35), "block")
        assert.is_true(block_range:contains(line_range))
      end)

      it("returns false for block range not containing a line range", function()
        local line_range = Range.new(Location.new(4, 0), Location.new(9, 1), "line")
        local block_range = Range.new(Location.new(5, 5), Location.new(8, 35), "block")
        assert.is_false(block_range:contains(line_range))
      end)

      it("returns true char range containing a line range", function()
        local range = Range.new(Location.new(5, 0), Location.new(8, 30))
        local line_range = Range.new(Location.new(6, 0), Location.new(7, 30), "line")
        assert.is_true(range:contains(line_range))
      end)

      it("returns false char range not containing a line range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local line_range = Range.new(Location.new(4, 0), Location.new(9, 1), "line")
        assert.is_false(range:contains(line_range))
      end)

      it("returns true for char range containing a block range", function()
        local range = Range.new(Location.new(5, 0), Location.new(8, 30))
        local block_range = Range.new(Location.new(6, 5), Location.new(7, 25), "block")
        assert.is_true(range:contains(block_range))
      end)

      it("returns false for char range not containing a block range", function()
        local range = Range.new(Location.new(5, 10), Location.new(8, 20))
        local block_range = Range.new(Location.new(4, 5), Location.new(9, 25), "block")
        assert.is_false(range:contains(block_range))
      end)
    end)
  end)

  describe("eq method", function()
    it("returns true for ranges with same start and stop", function()
      local r1 = Range.new(Location.new(5, 10), Location.new(8, 20))
      local r2 = Range.new(Location.new(5, 10), Location.new(8, 20))
      assert.is_true(r1:eq(r2))
    end)

    it("returns false for ranges with different start", function()
      local r1 = Range.new(Location.new(5, 10), Location.new(8, 20))
      local r2 = Range.new(Location.new(6, 10), Location.new(8, 20))
      assert.is_false(r1:eq(r2))
    end)

    it("returns false for ranges with different stop", function()
      local r1 = Range.new(Location.new(5, 10), Location.new(8, 20))
      local r2 = Range.new(Location.new(5, 10), Location.new(8, 21))
      assert.is_false(r1:eq(r2))
    end)

    it("returns false for ranges with different types", function()
      local r1 = Range.new(Location.new(5, 10), Location.new(8, 20))
      local r2 = Range.new(Location.new(5, 10), Location.new(8, 20), "line")
      local r3 = Range.new(Location.new(5, 10), Location.new(8, 20), "block")
      assert.is_false(r1:eq(r2))
      assert.is_false(r1:eq(r3))
      assert.is_false(r2:eq(r3))
    end)
  end)

  describe("integration tests", function()
    local bufnr

    before_each(function()
      bufnr = util.buffer({
        "hello world this is a test",
        "second line with more content",
        "", -- empty line 3
        "fourth line here",
      })
    end)

    after_each(function()
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)

    it("of_line creates ranges that contain cursor positions", function()
      local line_range = Range.of_line(1)
      vim.api.nvim_win_set_cursor(0, { 2, 10 }) -- line 2, col 10 (1-indexed)
      local cursor_loc = assert(Location.of_cursor())

      assert.is_true(line_range:contains(cursor_loc))
    end)

    it("range operations work together", function()
      local line_range = Range.of_line(0)
      local moved_range = line_range:move(Location.new(10, 5))

      -- Original range should be at line 0
      assert.equals(0, line_range.start.line)

      -- Moved range should be at line 10
      assert.equals(10, moved_range.start.line)
      assert.equals(5, moved_range.start.col)

      -- They should not be equal
      assert.is_false(line_range == moved_range)
    end)

    describe("of_line", function()
      it("returns range for specified line", function()
        local range = Range.of_line(1) -- 0-indexed line 1
        assert.equals(1, range.start.line)
        assert.equals(0, range.start.col)
        assert.equals(1, range.stop.line)
        assert.equals(30, range.stop.col) -- length of "second line with more content" + 1
      end)

      it("returns range for current line when no line specified", function()
        vim.api.nvim_win_set_cursor(0, { 4, 10 }) -- line 4 (1-indexed)
        local range = Range.of_line()
        assert.equals(3, range.start.line) -- 0-indexed
        assert.equals(0, range.start.col)
        assert.equals(3, range.stop.line)
        assert.equals(17, range.stop.col) -- length of "fourth line here" + 1
      end)

      it("handles empty lines", function()
        local range = Range.of_line(2) -- empty line
        assert.equals(2, range.start.line)
        assert.equals(0, range.start.col)
        assert.equals(2, range.stop.line)
        assert.equals(1, range.stop.col)
      end)
    end)

    describe("of_buffer", function()
      it("returns range for entire buffer", function()
        local range = Range.of_buffer()
        assert.equals(0, range.start.line)
        assert.equals(0, range.start.col)
        assert.equals(3, range.stop.line) -- last line (0-indexed)
        assert.equals(17, range.stop.col) -- length of "fourth line here" + 1
      end)
    end)

    describe("of_selection", function()
      it("returns nil if not in visual mode", function()
        -- In normal mode, should return nil
        local range = Range.of_selection()
        assert.is_nil(range)
      end)

      it("returns range for character-wise visual selection", function()
        -- Position cursor at start of selection
        vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- position at "world" in first line

        -- Enter visual mode and move cursor to create selection
        feedkeys("v")
        vim.api.nvim_win_set_cursor(0, { 1, 10 }) -- select "world"

        local range = assert(Range.of_selection())
        assert.equals(0, range.start.line) -- 0-indexed
        assert.equals(6, range.start.col)
        assert.equals(0, range.stop.line)
        -- Stop should be cursor + 1 (end-exclusive)
        assert.equals(11, range.stop.col)
        assert.equals("char", range.type)
      end)

      it("returns range for line-wise visual selection", function()
        -- Position cursor on second line
        vim.api.nvim_win_set_cursor(0, { 2, 10 })

        -- Enter line-wise visual mode
        feedkeys("V")

        local range = assert(Range.of_selection())
        assert.equals(1, range.start.line) -- 0-indexed line 1
        assert.equals(0, range.start.col) -- start of line
        assert.equals(1, range.stop.line)
        -- Should be end of line for line-wise selection
        assert.equals(30, range.stop.col) -- length of "second line with more content" + 1
        assert.equals("line", range.type)
      end)

      it("handles multi-line character-wise selection", function()
        -- Start selection on line 1
        vim.api.nvim_win_set_cursor(0, { 1, 6 })
        feedkeys("v")

        -- End selection on line 4
        vim.api.nvim_win_set_cursor(0, { 4, 10 })

        local range = assert(Range.of_selection())
        assert.equals(0, range.start.line)
        assert.equals(6, range.start.col)
        assert.equals(3, range.stop.line)
        assert.equals(11, range.stop.col)
        assert.equals("char", range.type)
      end)

      it("handles reversed selections correctly", function()
        -- Start at end position and select backwards
        vim.api.nvim_win_set_cursor(0, { 1, 15 })
        feedkeys("v")
        vim.api.nvim_win_set_cursor(0, { 1, 5 })

        local range = assert(Range.of_selection())
        -- Function should handle start > stop by swapping them
        assert.is_true(range.start.col <= range.stop.col)
      end)

      it("returns range for blockwise visual selection", function()
        vim.api.nvim_win_set_cursor(0, { 1, 5 })

        -- Try to enter blockwise visual mode (Ctrl-V)
        feedkeys.change_mode("^V") -- visual block mode

        -- End selection on line 4, col 10
        vim.api.nvim_win_set_cursor(0, { 4, 10 })

        -- Should error for blockwise mode
        assert.is_true(vim.api.nvim_get_mode().mode == "") -- visual block mode

        local range = assert(Range.of_selection())
        assert.equals(0, range.start.line)
        assert.equals(5, range.start.col)
        assert.equals(3, range.stop.line)
        assert.equals(11, range.stop.col) -- end-exclusive
        assert.equals("block", range.type)
      end)
    end)

    describe("of_motion", function()
      it("returns nil when no recent motion", function()
        -- In a fresh buffer with no motion, should return nil
        local range = Range.of_motion()
        assert.is_nil(range)
      end)

      it("handles char motion type after yank operation", function()
        -- Position cursor and yank some text to set marks
        vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- position in first line

        -- Yank word to set [ and ] marks
        feedkeys("yw")
        local range = assert(Range.of_motion("char"))
        -- Should have a range from the yank operation
        assert.equals(0, range.start.line)
        assert.equals(5, range.start.col)
      end)

      it("handles line motion type after yank operation", function()
        -- Position cursor and yank a line
        vim.api.nvim_win_set_cursor(0, { 2, 0 })

        -- Yank line to set marks
        feedkeys("yy")

        local range = assert(Range.of_motion("line"))
        -- Should span full lines
        assert.equals(1, range.start.line) -- 0-indexed
        assert.equals(0, range.start.col) -- start of line
        assert.equals(1, range.stop.line)
        assert.equals(30, range.stop.col) -- length of "second line with more content" + 1
      end)

      it("handles block motion type after yank operation", function()
        -- Position cursor and yank a block (simulate with visual block mode)
        vim.api.nvim_win_set_cursor(0, { 1, 5 })
        feedkeys.change_mode("^V") -- visual block mode
        vim.api.nvim_win_set_cursor(0, { 4, 10 }) -- select block to line 4, col 10
        vim.cmd("silent normal y") -- yank block

        local range = assert(Range.of_motion("block"))
        assert.equals(0, range.start.line)
        assert.equals(5, range.start.col)
        assert.equals(3, range.stop.line)
        assert.equals(11, range.stop.col) -- end-exclusive
      end)

      it("handles multi-line yank operations", function()
        -- Position cursor at start of line 2
        vim.api.nvim_win_set_cursor(0, { 2, 0 })

        -- Yank 3 lines
        local report = vim.opt.report
        vim.opt.report = 9999 -- suppress "3 lines yanked" message
        feedkeys("3yy")
        vim.opt.report = report

        local range = assert(Range.of_motion("line"))
        assert.equals(1, range.start.line) -- 0-indexed line 1
        assert.equals(0, range.start.col)
        assert.equals(3, range.stop.line) -- should include line 2
        assert.equals(17, range.stop.col) -- length of "fourth line here" + 1
      end)

      it("handles character range yanks", function()
        -- Position cursor and yank specific characters
        vim.api.nvim_win_set_cursor(0, { 1, 6 })

        -- Yank 5 characters
        feedkeys("5yl")

        local range = assert(Range.of_motion("char"))
        assert.equals(0, range.start.line)
        assert.equals(6, range.start.col)
        assert.equals(0, range.stop.line)
        assert.equals(11, range.stop.col) -- 6 + 5
      end)

      it("handles reversed mark order", function()
        -- Manually set marks in reverse order to test swapping
        vim.api.nvim_buf_set_mark(0, "[", 3, 10, {})
        vim.api.nvim_buf_set_mark(0, "]", 1, 5, {})

        local range = assert(Range.of_motion("char"))
        -- Function should swap start and stop if stop < start
        assert.is_true(range.start.line <= range.stop.line)
        if range.start.line == range.stop.line then
          assert.is_true(range.start.col <= range.stop.col)
        end
      end)

      it("handles change operations", function()
        -- Position cursor and perform a change operation
        vim.api.nvim_win_set_cursor(0, { 2, 0 })

        -- Change word (this should set marks)
        feedkeys("cw")
        feedkeys("<Esc>")

        local range = assert(Range.of_motion("char"))
        assert.equals(1, range.start.line)
        assert.equals(0, range.start.col)
        assert.equals(1, range.stop.line)
        assert.equals(1, range.stop.col)
      end)

      it("handles delete operations", function()
        -- Position cursor and delete some text
        vim.api.nvim_win_set_cursor(0, { 2, 5 })
        feedkeys("dw")

        local range = assert(Range.of_motion("char"))
        assert.equals(1, range.start.line) -- 0-indexed
        assert.equals(5, range.start.col)
        assert.equals(1, range.stop.line)
        assert.equals(6, range.stop.col)
      end)

      it("converts char motion to line motion correctly", function()
        -- Set up a character range
        vim.api.nvim_win_set_cursor(0, { 2, 10 })
        feedkeys("yw")

        -- Get both char and line versions of the same motion
        local char_range = assert(Range.of_motion("char"))
        local line_range = assert(Range.of_motion("line"))

        -- Line range should start at column 0
        assert.equals(0, line_range.start.col)
        -- Line range should be on same line as char range
        assert.equals(char_range.start.line, line_range.start.line)
        assert.equals(char_range.stop.line, line_range.stop.line)
        -- Line range should extend to end of line
        assert.is_true(line_range.stop.col > char_range.stop.col)
      end)

      it("converts char motion to block motion correctly", function()
        -- Set up a character range
        vim.api.nvim_win_set_cursor(0, { 1, 5 })
        feedkeys("yw")

        -- Get both char and block versions of the same motion
        local char_range = assert(Range.of_motion("char"))
        local block_range = assert(Range.of_motion("block"))

        -- Block range should start at same position as char range
        assert.equals(char_range.start.line, block_range.start.line)
        assert.equals(char_range.start.col, block_range.start.col)
        -- Block range should end at same position as char range
        assert.equals(char_range.stop.line, block_range.stop.line)
        assert.equals(char_range.stop.col, block_range.stop.col)
      end)

      it("converts line motion to char motion correctly", function()
        -- Set up a line range
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        feedkeys("yy")

        -- Get both line and char versions of the same motion
        local line_range = assert(Range.of_motion("line"))
        local char_range = assert(Range.of_motion("char"))

        -- Char range should start at beginning of line
        assert.equals(line_range.start.line, char_range.start.line)
        assert.equals(0, char_range.start.col)
        -- Char range should end at end of line
        assert.equals(line_range.stop.line, char_range.stop.line)
        -- Char range should end at max col (-1 for 0-indexed)
        assert.equals(char_range.stop.col, vim.v.maxcol - 1)
        assert.is_true(line_range.stop.col < char_range.stop.col)
      end)

      it("converts line motion to block motion correctly", function()
        -- Set up a line range
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        feedkeys("yy")

        -- Get both line and block versions of the same motion
        local line_range = assert(Range.of_motion("line"))
        local block_range = assert(Range.of_motion("block"))

        -- Block range should start at same position as line range
        assert.equals(line_range.start.line, block_range.start.line)
        assert.equals(line_range.start.col, block_range.start.col)
        -- Block range should end at max col (-1 for 0-indexed)
        assert.equals(block_range.stop.col, vim.v.maxcol - 1)
        assert.is_true(line_range.stop.col < block_range.stop.col)
      end)
    end)
  end)
end)
