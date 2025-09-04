local assert = require("luassert")
local util = require("tests.util")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")
local Extmarks = require("occurrence.Extmarks")

local NS = vim.api.nvim_create_namespace("Occurrence")

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

  describe("extmarks.new", function()
    it("creates new Extmarks object", function()
      local extmarks = Extmarks.new()

      assert.is_table(extmarks)
      assert.is_function(extmarks.has)
      assert.is_function(extmarks.add)
      assert.is_function(extmarks.get)
      assert.is_function(extmarks.del)
      assert.is_function(extmarks.iter)
    end)

    it("creates independent Extmarks instances", function()
      local extmarks1 = Extmarks.new()
      local extmarks2 = Extmarks.new()

      assert.is_not.equal(extmarks1, extmarks2)

      -- Adding to one shouldn't affect the other
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      local buf = vim.api.nvim_get_current_buf()

      extmarks1:add(buf, range)
      assert.is_true(extmarks1:has(range))
      assert.is_false(extmarks2:has(range))
    end)
  end)

  describe("Extmarks:has", function()
    local extmarks, buf

    before_each(function()
      extmarks = Extmarks.new()
      buf = vim.api.nvim_get_current_buf()
    end)

    it("returns false for nil", function()
      assert.is_false(extmarks:has(nil))
    end)

    it("returns false for non-existent range", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 5))
      assert.is_false(extmarks:has(range))
    end)

    it("returns false for non-existent id", function()
      assert.is_false(extmarks:has(99999))
    end)

    it("returns true for existing range", function()
      local range = Range.new(Location.new(0, 5), Location.new(0, 10))
      extmarks:add(buf, range)

      assert.is_true(extmarks:has(range))
    end)

    it("returns true for existing id", function()
      local range = Range.new(Location.new(1, 0), Location.new(1, 8))
      extmarks:add(buf, range)
      local id = vim.api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})[1][1]
      assert.is_not_nil(id)
      assert.is_true(extmarks:has(id))
    end)
  end)

  describe("Extmarks:add", function()
    local extmarks, buf

    before_each(function()
      extmarks = Extmarks.new()
      buf = vim.api.nvim_get_current_buf()
    end)

    it("adds extmark for range and returns true", function()
      local range = Range.new(Location.new(0, 5), Location.new(0, 10))

      local added = extmarks:add(buf, range)

      assert.is_true(added)
      assert.is_true(extmarks:has(range))
    end)

    it("does not add duplicate extmarks", function()
      local range = Range.new(Location.new(1, 2), Location.new(1, 8))

      local added1 = extmarks:add(buf, range)
      local added2 = extmarks:add(buf, range)

      assert.is_true(added1)
      assert.is_false(added2) -- second add should return false
    end)

    it("adds extmarks for different ranges", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 0), Location.new(1, 5))

      local added1 = extmarks:add(buf, range1)
      local added2 = extmarks:add(buf, range2)

      assert.is_true(added1)
      assert.is_true(added2)
      assert.is_true(extmarks:has(range1))
      assert.is_true(extmarks:has(range2))
    end)

    it("creates extmarks with correct properties", function()
      local range = Range.new(Location.new(0, 5), Location.new(0, 15))
      extmarks:add(buf, range)

      -- Check that vim extmark was created
      local marks = vim.api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})
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

      local added = extmarks:add(buf, range)

      assert.is_true(added)
      assert.is_true(extmarks:has(range))
    end)

    it("handles zero-width ranges", function()
      local range = Range.new(Location.new(1, 5), Location.new(1, 5))

      local added = extmarks:add(buf, range)
      assert.is_true(added)
      assert.is_true(extmarks:has(range))
    end)

    it("handles ranges at buffer boundaries", function()
      -- Start of buffer
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      assert.is_true(extmarks:add(buf, range1))

      -- End of buffer (approximately)
      local range2 = Range.new(Location.new(4, 30), Location.new(4, 35))
      assert.is_true(extmarks:add(buf, range2))

      assert.is_true(extmarks:has(range1))
      assert.is_true(extmarks:has(range2))
    end)
  end)

  describe("Extmarks:get", function()
    local extmarks, buf

    before_each(function()
      extmarks = Extmarks.new()
      buf = vim.api.nvim_get_current_buf()
    end)

    it("returns current range for existing extmark by range", function()
      local original_range = Range.new(Location.new(1, 5), Location.new(1, 15))
      extmarks:add(buf, original_range)

      local current_range = extmarks:get(buf, original_range)

      assert.same({ 1, 5, 1, 15 }, current_range)
    end)

    it("returns current range for existing extmark by id", function()
      local range = Range.new(Location.new(0, 8), Location.new(0, 18))
      extmarks:add(buf, range)

      local id = vim.api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})[1][1]
      local current_range = extmarks:get(buf, id)

      assert.same({ 0, 8, 0, 18 }, current_range)
    end)

    it("returns nil for non-existent extmark", function()
      local range = Range.new(Location.new(2, 0), Location.new(2, 5))

      local current_range = extmarks:get(buf, range)

      assert.is_nil(current_range)
    end)

    it("returns updated range after buffer modifications", function()
      local range = Range.new(Location.new(1, 0), Location.new(1, 6))
      extmarks:add(buf, range)

      local current_range = extmarks:get(buf, range)

      assert.is_true(range == current_range)
      assert.same({ 1, 0, 1, 6 }, current_range)

      -- Modify buffer to shift the extmark
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "new first line content" })

      current_range = extmarks:get(buf, range)

      assert.is_false(range == current_range)

      assert.same({ 2, 0, 2, 6 }, current_range) -- should have shifted down

      -- Further modify buffer to insert text before the extmark to shift it right
      vim.api.nvim_buf_set_text(buf, 2, 0, 2, 0, { "old " })

      current_range = extmarks:get(buf, range)
      assert.same({ 2, 4, 2, 10 }, current_range) -- should have shifted right
    end)
  end)

  describe("Extmarks:del", function()
    local extmarks, buf

    before_each(function()
      extmarks = Extmarks.new()
      buf = vim.api.nvim_get_current_buf()
    end)

    it("deletes extmark by range and returns true", function()
      local range = Range.new(Location.new(0, 3), Location.new(0, 8))
      extmarks:add(buf, range)

      local deleted = extmarks:del(buf, range)

      assert.is_true(deleted)
      assert.is_false(extmarks:has(range))
    end)

    it("deletes extmark by id and returns true", function()
      local range = Range.new(Location.new(1, 5), Location.new(1, 12))
      extmarks:add(buf, range)

      local id = vim.api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})[1][1]

      local deleted = extmarks:del(buf, id)

      assert.is_true(deleted)
      assert.is_false(extmarks:has(range))
      assert.is_false(extmarks:has(id))
    end)

    it("returns false for non-existent extmark", function()
      local range = Range.new(Location.new(2, 0), Location.new(2, 5))

      local deleted = extmarks:del(buf, range)

      assert.is_false(deleted)
    end)

    it("removes extmark from buffer", function()
      local range = Range.new(Location.new(0, 0), Location.new(0, 10))
      extmarks:add(buf, range)

      -- Verify extmark exists in vim
      local marks_before = vim.api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})
      local count_before = #marks_before

      extmarks:del(buf, range)

      -- Verify extmark was removed from vim
      local marks_after = vim.api.nvim_buf_get_extmarks(buf, NS, 0, -1, {})
      local count_after = #marks_after

      assert.is_true(count_after < count_before)
    end)

    it("cleans up internal tracking", function()
      local range = Range.new(Location.new(2, 3), Location.new(2, 8))
      extmarks:add(buf, range)

      local key = range:serialize()
      local id = extmarks[key]

      extmarks:del(buf, range)

      -- Internal tracking should be cleaned up
      assert.is_nil(extmarks[key])
      assert.is_nil(extmarks[id])
    end)
  end)

  describe("Extmarks:iter", function()
    local extmarks, buf

    before_each(function()
      extmarks = Extmarks.new()
      buf = vim.api.nvim_get_current_buf()
    end)

    it("iterates over all extmarks when no range specified", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 5), Location.new(1, 10))
      local range3 = Range.new(Location.new(2, 10), Location.new(2, 15))

      extmarks:add(buf, range1)
      extmarks:add(buf, range2)
      extmarks:add(buf, range3)

      local count = 0
      for original, current in extmarks:iter(buf) do
        count = count + 1
        assert.is_not_nil(original)
        assert.is_not_nil(current)
        assert.is_table(original)
        assert.is_table(current)
      end

      assert.equals(3, count)
    end)

    it("iterates over extmarks within specified range", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 5), Location.new(1, 10))
      local range3 = Range.new(Location.new(3, 10), Location.new(3, 15))

      extmarks:add(buf, range1)
      extmarks:add(buf, range2)
      extmarks:add(buf, range3)

      -- Only iterate over lines 0-2
      local search_range = Range.new(Location.new(0, 0), Location.new(2, 0))

      local count = 0
      for original in extmarks:iter(buf, { range = search_range }) do
        count = count + 1
        assert.is_true(original.start.line < 3) -- should not include line 3
      end

      assert.is_true(count >= 2) -- should include range1 and range2
    end)

    it("returns original and current ranges", function()
      local first_range = Range.new(Location.new(1, 0), Location.new(1, 8))
      extmarks:add(buf, first_range)
      local second_range = Range.new(Location.new(2, 5), Location.new(2, 15))
      extmarks:add(buf, second_range)

      local marks = extmarks:iter(buf)

      local original, current = marks()
      assert.same({ 1, 0, 1, 8 }, original)
      assert.same(original, current)

      -- modify buffer to shift the next extmark
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted line at top" })
      original, current = marks()
      assert.same({ 2, 5, 2, 15 }, original)
      assert.same({ 3, 5, 3, 15 }, current) -- should have shifted down
    end)

    it("handles reverse iteration option", function()
      local range1 = Range.new(Location.new(0, 0), Location.new(0, 5))
      local range2 = Range.new(Location.new(1, 0), Location.new(1, 5))

      extmarks:add(buf, range1)
      extmarks:add(buf, range2)

      local ranges = {}
      for original in extmarks:iter(buf, { reverse = true }) do
        table.insert(ranges, original)
      end

      assert.same({ range2, range1 }, ranges)
    end)
  end)
end)
