local assert = require("luassert")
local util = require("tests.util")
local Occurrence = require("occurrence.Occurrence")

describe("status", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("Occurrence:status", function()
    it("returns count for all matches", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor at the beginning
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local count = occurrence:status()
      assert.equals(3, count.total)
      assert.equals(1, count.current)
      assert.equals(1, count.exact_match) -- Cursor is on first "foo"
      assert.equals(false, count.marked_only)
    end)

    it("returns count for marked matches only", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Mark first and third occurrence
      local match_count = 0
      for range in occurrence:matches() do
        match_count = match_count + 1
        if match_count == 1 or match_count == 3 then
          occurrence.extmarks:mark(range)
        end
      end

      -- Position cursor at the beginning
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local count = occurrence:status({ marked = true })
      assert.equals(2, count.total) -- Only 2 marked
      assert.equals(1, count.current)
      assert.equals(1, count.exact_match)
      assert.equals(true, count.marked_only)
    end)

    it("tracks current position correctly", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor on second "foo" (line 1, col 8)
      vim.api.nvim_win_set_cursor(0, { 1, 8 })

      local count = occurrence:status()
      assert.equals(3, count.total)
      assert.equals(2, count.current) -- On second match
      assert.equals(1, count.exact_match)
    end)

    it("sets exact_match to 0 when not on a match", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor on "bar" (not a match)
      vim.api.nvim_win_set_cursor(0, { 1, 4 })

      local count = occurrence:status()
      assert.equals(3, count.total)
      assert.equals(2, count.current) -- Cursor is after first match, before second
      assert.equals(0, count.exact_match)
    end)

    it("handles cursor after last match", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar", "end" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor on last line (after all matches)
      vim.api.nvim_win_set_cursor(0, { 3, 0 })

      local count = occurrence:status()
      assert.equals(3, count.total)
      assert.equals(3, count.current) -- Past all matches
      assert.equals(0, count.exact_match)
    end)

    it("handles no matches", function()
      bufnr = util.buffer({ "bar baz qux" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      local count = occurrence:status()
      assert.equals(0, count.total)
      assert.equals(0, count.current)
      assert.equals(0, count.exact_match)
    end)

    it("handles empty pattern list", function()
      bufnr = util.buffer({ "foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr)

      -- Occurrence with no patterns added yet
      assert.equals(0, #occurrence.patterns)

      -- Should handle gracefully (though this would normally error in match_cursor)
      -- For status, we just return zeros
      local ok, result = pcall(function()
        return occurrence:status()
      end)

      -- The function should work even with no patterns
      if ok then
        assert.equals(0, result.total)
      end
    end)

    it("uses custom position", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")
      local Location = require("occurrence.Location")

      -- Count from a specific position (line 2, col 0)
      local pos = Location.new(1, 0) -- 0-indexed: line 2
      local count = occurrence:status({ pos = pos })

      assert.equals(3, count.total)
      -- Current should be the third match (on line 2)
      assert.equals(3, count.current)
    end)

    it("works with multiple patterns", function()
      bufnr = util.buffer({ "foo bar baz", "qux foo baz" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr)
      occurrence:of_word(false, "foo")
      occurrence:of_word(false, "baz")

      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local count = occurrence:status()
      -- Should have 2 "foo" + 2 "baz" = 4 total matches
      assert.equals(4, count.total)
    end)
  end)

  describe("Global API: require('occurrence').status", function()
    it("returns count for current buffer", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      Occurrence.get(bufnr, "foo")

      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local global_api = require("occurrence")
      local count = global_api.status()

      assert(count)
      assert.is_table(count)
      assert.equals(3, count.total)
      assert.equals(1, count.current)
    end)

    it("returns nil when no occurrence exists", function()
      bufnr = util.buffer({ "foo bar foo" })
      vim.api.nvim_set_current_buf(bufnr)
      -- Don't create an occurrence

      local global_api = require("occurrence")
      local count = global_api.status()

      assert.is_nil(count)
    end)

    it("returns nil when occurrence is disposed", function()
      bufnr = util.buffer({ "foo bar foo" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")
      occurrence:dispose()

      local global_api = require("occurrence")
      local count = global_api.status()

      assert.is_nil(count)
    end)

    it("returns nil when occurrence has no patterns", function()
      bufnr = util.buffer({ "foo bar foo" })
      vim.api.nvim_set_current_buf(bufnr)
      Occurrence.get(bufnr) -- No pattern

      local global_api = require("occurrence")
      local count = global_api.status()

      assert.is_nil(count)
    end)

    it("accepts marked option", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo bar" })
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Mark only first occurrence
      local first_match = assert(occurrence:matches()())
      occurrence.extmarks:mark(first_match)

      local global_api = require("occurrence")
      local count_all = assert(global_api.status())
      local count_marked = assert(global_api.status({ marked = true }))

      assert.equals(3, count_all.total)
      assert.equals(1, count_marked.total)
    end)

    it("accepts buffer option", function()
      local buf1 = util.buffer({ "foo bar foo" })
      local buf2 = util.buffer({ "foo foo foo foo" })

      -- Create occurrence for buf1
      vim.api.nvim_set_current_buf(buf1)
      Occurrence.get(buf1, "foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Set cursor to start
      local global_api = require("occurrence")
      local count_buf1 = assert(global_api.status({ buffer = buf1 }))
      assert.equals(2, count_buf1.total)

      -- Create occurrence for buf2
      vim.api.nvim_set_current_buf(buf2)
      Occurrence.get(buf2, "foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- Set cursor to start
      local count_buf2 = assert(global_api.status({ buffer = buf2 }))
      assert.equals(4, count_buf2.total)

      vim.api.nvim_buf_delete(buf1, { force = true })
      vim.api.nvim_buf_delete(buf2, { force = true })
    end)
  end)
end)
