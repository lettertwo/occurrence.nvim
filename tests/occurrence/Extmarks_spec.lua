local assert = require("luassert")
local util = require("tests.util")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")
local Extmarks = require("occurrence.Extmarks")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

describe("Extmarks", function()
  local bufnr

  before_each(function()
    bufnr = util.buffer({
      "first line of text content here",
      "second line with more detailed content",
      "third line for extmark testing purposes",
      "fourth line is shorter than others",
      "fifth and final line of the test buffer",
    })
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe(".new", function()
    it("creates new Extmarks object", function()
      local extmarks = Extmarks.new()

      assert.is_table(extmarks)
      assert.is_function(extmarks.has_mark)
      assert.is_function(extmarks.has_any_marks)
      assert.is_function(extmarks.mark)
      assert.is_function(extmarks.get_mark)
      assert.is_function(extmarks.unmark)
      assert.is_function(extmarks.iter)
    end)

    it("creates independent Extmarks instances", function()
      local extmarks1 = Extmarks.new()
      local extmarks2 = Extmarks.new()

      assert.is_not.equal(extmarks1, extmarks2)

      -- Adding to one shouldn't affect the other
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))

      extmarks1:mark(range)
      assert.is_true(extmarks1:has_mark(range))
      assert.is_false(extmarks2:has_mark(range))
    end)
  end)

  describe(":has_any", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("returns false when no extmarks exist", function()
      assert.is_false(extmarks:has_any_marks())
    end)

    it("returns true when at least one extmark exists", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      extmarks:mark(range)

      assert.is_true(extmarks:has_any_marks())
    end)

    it("returns false after all extmarks are deleted", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 0), Location.new(1, 5))
      extmarks:mark(range1)
      extmarks:mark(range2)

      assert.is_true(extmarks:has_any_marks())

      extmarks:unmark(range1)
      assert.is_true(extmarks:has_any_marks())

      extmarks:unmark(range2)
      assert.is_false(extmarks:has_any_marks())
    end)

    it("returns false when no extmarks are in the given range", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      extmarks:mark(range1)

      local search_range = Range.new(Location.new(1, 0), Location.new(1, 5))
      assert.is_true(extmarks:has_any_marks()) -- extmarks exist
      assert.is_false(extmarks:has_any_marks(search_range))
    end)

    it("returns true when at least one extmark is in the given range", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 0), Location.new(1, 5))
      extmarks:mark(range1)
      extmarks:mark(range2)

      local search_range = Range.new(Location.new(0, 3), Location.new(1, 2))
      assert.is_true(extmarks:has_any_marks()) -- extmarks exist
      assert.is_true(extmarks:has_any_marks(search_range))
    end)
  end)

  describe(":has", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("returns false for nil", function()
      assert.is_false(extmarks:has_mark(nil))
    end)

    it("returns false for non-existent range", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      assert.is_false(extmarks:has_mark(range))
    end)

    it("returns false for non-existent id", function()
      assert.is_false(extmarks:has_mark(99999))
    end)

    it("returns true for existing range", function()
      local range = Range.new(Location.new(0, 5), Location.new(0, 10))
      extmarks:mark(range)

      assert.is_true(extmarks:has_mark(range))
    end)

    it("returns true for existing id", function()
      local range = Range.new(Location.new(1, 0), Location.new(1, 8))
      extmarks:mark(range)
      local id = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})[1][1]
      assert.is_not_nil(id)
      assert.is_true(extmarks:has_mark(id))
    end)
  end)

  describe(":add", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("adds extmark for range and returns true", function()
      local range = Range.new(Location.new(0, 5), Location.new(0, 10))

      local added = extmarks:mark(range)

      assert.is_true(added)
      assert.is_true(extmarks:has_mark(range))
    end)

    it("does not add duplicate extmarks", function()
      local range = Range.new(Location.new(1, 2), Location.new(1, 8))

      local added1 = extmarks:mark(range)
      local added2 = extmarks:mark(range)

      assert.is_true(added1)
      assert.is_false(added2) -- second add should return false
    end)

    it("adds extmarks for different ranges", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 0), Location.new(1, 5))

      local added1 = extmarks:mark(range1)
      local added2 = extmarks:mark(range2)

      assert.is_true(added1)
      assert.is_true(added2)
      assert.is_true(extmarks:has_mark(range1))
      assert.is_true(extmarks:has_mark(range2))
    end)

    it("creates extmarks with correct properties", function()
      local range = Range.new(Location.new(0, 5), Location.new(0, 15))
      extmarks:mark(range)

      -- Check that vim extmark was created
      local marks = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})
      assert.is_true(#marks > 0)

      -- Check extmark properties
      local mark = marks[1]
      local id, row, col = mark[1], mark[2], mark[3]
      assert.is_number(id)
      assert.equals(0, row) -- 0-indexed
      assert.equals(5, col)
    end)

    it("handles multi-line ranges", function()
      local range = Range.new(Location.new(1, 5), Location.new(3, 10))

      local added = extmarks:mark(range)

      assert.is_true(added)
      assert.is_true(extmarks:has_mark(range))
    end)

    it("handles zero-width ranges", function()
      local range = Range.new(Location.new(1, 5), Location.new(1, 5))

      local added = extmarks:mark(range)
      assert.is_true(added)
      assert.is_true(extmarks:has_mark(range))
    end)

    it("handles ranges at buffer boundaries", function()
      -- Start of buffer
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      assert.is_true(extmarks:mark(range1))

      -- End of buffer (approximately)
      local range2 = Range.new(Location.new(4, 30), Location.new(4, 35))
      assert.is_true(extmarks:mark(range2))

      assert.is_true(extmarks:has_mark(range1))
      assert.is_true(extmarks:has_mark(range2))
    end)
  end)

  describe(":get", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("returns current range for existing extmark by range", function()
      local original_range = Range.new(Location.new(1, 5), Location.new(1, 15))
      extmarks:mark(original_range)

      local current_range = extmarks:get_mark(original_range)

      assert.same({ 1, 5, 1, 15 }, current_range)
    end)

    it("returns current range for existing extmark by id", function()
      local range = Range.new(Location.new(0, 8), Location.new(0, 18))
      extmarks:mark(range)

      local id = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})[1][1]
      local current_range = extmarks:get_mark(id)

      assert.same({ 0, 8, 0, 18 }, current_range)
    end)

    it("returns nil for non-existent extmark", function()
      local range = Range.new(Location.new(2, 0), Location.new(2, 5))

      local current_range = extmarks:get_mark(range)

      assert.is_nil(current_range)
    end)

    it("returns updated range after buffer modifications", function()
      local range = Range.new(Location.new(1, 0), Location.new(1, 6))
      extmarks:mark(range)

      local current_range = extmarks:get_mark(range)

      assert.is_true(range == current_range)
      assert.same({ 1, 0, 1, 6 }, current_range)

      -- Modify buffer to shift the extmark
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { "new first line content" })

      current_range = extmarks:get_mark(range)

      assert.is_false(range == current_range)

      assert.same({ 2, 0, 2, 6 }, current_range) -- should have shifted down

      -- Further modify buffer to insert text before the extmark to shift it right
      vim.api.nvim_buf_set_text(0, 2, 0, 2, 0, { "old " })

      current_range = extmarks:get_mark(range)
      assert.same({ 2, 4, 2, 10 }, current_range) -- should have shifted right
    end)
  end)

  describe(":del", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("deletes extmark by range and returns true", function()
      local range = Range.new(Location.new(0, 3), Location.new(0, 8))
      extmarks:mark(range)

      local deleted = extmarks:unmark(range)

      assert.is_true(deleted)
      assert.is_false(extmarks:has_mark(range))
    end)

    it("deletes extmark by id and returns true", function()
      local range = Range.new(Location.new(1, 5), Location.new(1, 12))
      extmarks:mark(range)

      local id = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})[1][1]

      local deleted = extmarks:unmark(id)

      assert.is_true(deleted)
      assert.is_false(extmarks:has_mark(range))
      assert.is_false(extmarks:has_mark(id))
    end)

    it("returns false for non-existent extmark", function()
      local range = Range.new(Location.new(2, 0), Location.new(2, 5))

      local deleted = extmarks:unmark(range)

      assert.is_false(deleted)
    end)

    it("removes extmark from buffer", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 10))
      extmarks:mark(range)

      -- Verify extmark exists in vim
      local marks_before = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})
      local count_before = #marks_before

      extmarks:unmark(range)

      -- Verify extmark was removed from vim
      local marks_after = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})
      local count_after = #marks_after

      assert.is_true(count_after < count_before)
    end)

    it("cleans up internal tracking", function()
      local range = Range.new(Location.new(2, 3), Location.new(2, 8))
      extmarks:mark(range)

      local key = range:serialize()
      local id = extmarks[key]

      extmarks:unmark(range)

      -- Internal tracking should be cleaned up
      assert.is_nil(extmarks[key])
      assert.is_nil(extmarks[id])
    end)
  end)

  describe(":iter", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("iterates over all extmarks when no range specified", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 5), Location.new(1, 10))
      local range3 = Range.new(Location.new(2, 10), Location.new(2, 15))

      extmarks:mark(range1)
      extmarks:mark(range2)
      extmarks:mark(range3)

      local count = 0
      for id, current in extmarks:iter() do
        count = count + 1
        assert.is_not_nil(id)
        assert.is_not_nil(current)
        assert.is_number(id)
        assert.is_table(current)
      end

      assert.equals(3, count)
    end)

    it("iterates over extmarks within specified range", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 5), Location.new(1, 10))
      local range3 = Range.new(Location.new(3, 10), Location.new(3, 15))

      extmarks:mark(range1)
      extmarks:mark(range2)
      extmarks:mark(range3)

      -- Only iterate over lines 0-2
      local search_range = Range.new(Location.new(0, 0), Location.new(2, 0))

      local count = 0
      for _, original in extmarks:iter(search_range) do
        count = count + 1
        assert.is_true(original.start.line < 3) -- should not include line 3
      end

      assert.is_true(count >= 2) -- should include range1 and range2
    end)

    it("returns id and current ranges", function()
      local first_range = Range.new(Location.new(1, 0), Location.new(1, 8))
      extmarks:mark(first_range)
      local second_range = Range.new(Location.new(2, 5), Location.new(2, 15))
      extmarks:mark(second_range)

      local marks = extmarks:iter()

      local id, current = marks()
      assert.is_number(id)
      assert.same(first_range, current)

      -- modify buffer to shift the next extmark
      vim.api.nvim_buf_set_lines(0, 0, 0, false, { "inserted line at top" })
      -- get next mark
      id, current = marks()
      assert.is_number(id)
      assert.not_same(second_range, current)
      assert.same({ 3, 5, 3, 15 }, current) -- should have shifted down
    end)
  end)

  describe(":clear", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("clears all extmarks from buffer and internal tracking", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 5), Location.new(1, 10))

      extmarks:mark(range1)
      extmarks:mark(range2)

      assert.is_true(extmarks:has_any_marks())

      -- Verify extmarks exist in buffer
      local marks = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})
      assert.equals(2, #marks)

      extmarks:clear()

      assert.is_false(extmarks:has_any_marks())

      -- Verify no extmarks exist in buffer
      marks = vim.api.nvim_buf_get_extmarks(0, MARK_NS, 0, -1, {})
      assert.equals(0, #marks)
    end)
  end)

  describe(":dispose", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("clears extmarks and makes instance unusable", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      extmarks:mark(range)

      assert.is_true(extmarks:has_any_marks())

      extmarks:dispose()

      assert.is_false(extmarks:has_any_marks())

      assert.has_error(function()
        extmarks:mark(range)
      end, "Cannot use a disposed Extmarks")

      assert.has_error(function()
        extmarks:unmark(range)
      end, "Cannot use a disposed Extmarks")

      assert.has_error(function()
        extmarks:clear()
      end, "Cannot use a disposed Extmarks")
    end)
  end)

  describe("highlight groups", function()
    ---@type occurrence.Extmarks
    local extmarks

    before_each(function()
      extmarks = Extmarks.new()
    end)

    it("uses OccurrenceMark for mark extmarks", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      extmarks:mark(range)

      local marks = vim.api.nvim_buf_get_extmarks(extmarks.buffer, MARK_NS, 0, -1, { details = true })
      assert.is_equal(1, #marks)
      assert.is_equal("OccurrenceMark", marks[1][4].hl_group)
    end)

    it("uses OccurrenceMatch for match extmarks", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      extmarks:add(range)

      local MATCH_NS = vim.api.nvim_create_namespace("OccurrenceMatch")
      local marks = vim.api.nvim_buf_get_extmarks(extmarks.buffer, MATCH_NS, 0, -1, { details = true })
      assert.is_equal(1, #marks)
      assert.is_equal("OccurrenceMatch", marks[1][4].hl_group)
    end)

    it("defaults to mark type when no type specified", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      extmarks:mark(range)

      local marks = vim.api.nvim_buf_get_extmarks(extmarks.buffer, MARK_NS, 0, -1, { details = true })
      assert.is_equal(1, #marks)
      assert.is_equal("OccurrenceMark", marks[1][4].hl_group)
    end)

    it("allows users to override highlight groups", function()
      -- Override the highlight groups
      vim.api.nvim_set_hl(0, "OccurrenceMark", { bg = "#ff0000" })
      vim.api.nvim_set_hl(0, "OccurrenceMatch", { bg = "#00ff00" })

      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 0), Location.new(1, 5))
      extmarks:mark(range1) -- Adds to both MARK_NS and MATCH_NS
      extmarks:add(range2) -- Adds only to MATCH_NS

      local MATCH_NS = vim.api.nvim_create_namespace("OccurrenceMatch")
      local mark_marks = vim.api.nvim_buf_get_extmarks(extmarks.buffer, MARK_NS, 0, -1, { details = true })
      local match_marks = vim.api.nvim_buf_get_extmarks(extmarks.buffer, MATCH_NS, 0, -1, { details = true })
      assert.is_equal(1, #mark_marks) -- Only range1 is marked
      assert.is_equal(2, #match_marks) -- Both range1 and range2 are matches
      assert.is_equal("OccurrenceMark", mark_marks[1][4].hl_group)
      assert.is_equal("OccurrenceMatch", match_marks[1][4].hl_group)
      assert.is_equal("OccurrenceMatch", match_marks[2][4].hl_group)

      -- Verify the highlight groups have our custom colors
      local mark_hl = vim.api.nvim_get_hl(0, { name = "OccurrenceMark" })
      local match_hl = vim.api.nvim_get_hl(0, { name = "OccurrenceMatch" })
      assert.is_equal(0xff0000, mark_hl.bg)
      assert.is_equal(0x00ff00, match_hl.bg)
    end)
  end)
end)
