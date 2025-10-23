local assert = require("luassert")
local util = require("tests.util")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")
local Location = require("occurrence.Location")

describe("Performance Tests", function()
  local bufnr
  local large_content
  local huge_content

  -- Helper function to get memory usage in KB
  local function get_memory_usage()
    collectgarbage("collect")
    return collectgarbage("count")
  end

  -- Helper function to measure memory delta
  local function measure_memory(fn)
    local before = get_memory_usage()
    fn()
    local after = get_memory_usage()
    return after - before
  end

  -- Generate test content of various sizes
  before_each(function()
    -- Large content: 1000 lines with repeated patterns
    large_content = {}
    for i = 1, 1000 do
      local line = string.format("line %d with content and pattern_%d and more text", i, i % 100)
      table.insert(large_content, line)
    end

    -- Huge content: 10000 lines with many occurrences
    huge_content = {}
    for i = 1, 10000 do
      local patterns = { "foo", "bar", "baz", "qux" }
      local pattern = patterns[(i % 4) + 1]
      local line = string.format("This is %s line %d with %s and some %s text", pattern, i, pattern, pattern)
      table.insert(huge_content, line)
    end
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe("Pattern Matching Performance", function()
    it("handles large buffers efficiently", function()
      bufnr = util.buffer(large_content)
      local start_time = vim.loop.hrtime()

      local occurrence = Occurrence.get(bufnr, "content")
      assert.is_true(occurrence:has_matches())

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6 -- Convert to milliseconds
      assert.is_true(elapsed < 100, "Pattern matching took too long: " .. elapsed .. "ms")
    end)

    it("handles multiple patterns efficiently", function()
      bufnr = util.buffer(large_content)
      local start_time = vim.loop.hrtime()

      local occurrence = Occurrence.get(bufnr)
      occurrence:add_pattern("content", "word")
      occurrence:add_pattern("pattern", "word")
      occurrence:add_pattern("line", "word")
      occurrence:add_pattern("text", "word")

      assert.is_true(occurrence:has_matches())

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6
      assert.is_true(elapsed < 200, "Multiple pattern matching took too long: " .. elapsed .. "ms")
    end)

    it("iterates through matches efficiently", function()
      bufnr = util.buffer(large_content)
      local occurrence = Occurrence.get(bufnr, "content")

      local start_time = vim.loop.hrtime()
      local count = 0
      for _ in occurrence:matches() do
        count = count + 1
      end
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(count > 0, "Should find matches")
      assert.is_true(elapsed < 150, "Match iteration took too long: " .. elapsed .. "ms")
    end)
  end)

  describe("Extmark Performance", function()
    it("marks many occurrences efficiently", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")

      local start_time = vim.loop.hrtime()
      local marked = occurrence:mark()
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(marked, "Should successfully mark occurrences")
      assert.is_true(elapsed < 1000, "Marking many occurrences took too long: " .. elapsed .. "ms")
    end)

    it("unmarks many occurrences efficiently", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")
      occurrence:mark() -- Mark first

      local start_time = vim.loop.hrtime()
      local unmarked = occurrence:unmark()
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(unmarked, "Should successfully unmark occurrences")
      assert.is_true(elapsed < 500, "Unmarking many occurrences took too long: " .. elapsed .. "ms")
    end)

    it("iterates through marks efficiently", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")
      occurrence:mark()

      local start_time = vim.loop.hrtime()
      local count = 0
      for _ in occurrence.extmarks:iter_marks() do
        count = count + 1
      end
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(count > 0, "Should find marks")
      assert.is_true(elapsed < 200, "Mark iteration took too long: " .. elapsed .. "ms")
    end)
  end)

  describe("Search Performance", function()
    it("finds cursor matches efficiently in large buffers", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor in the middle
      vim.api.nvim_win_set_cursor(0, { 5000, 10 })

      local start_time = vim.loop.hrtime()
      local match = occurrence:match_cursor()
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_not_nil(match, "Should find a match")
      assert.is_true(elapsed < 50, "Cursor match took too long: " .. elapsed .. "ms")
    end)

    it("handles wrapped search efficiently", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor near the end
      vim.api.nvim_win_set_cursor(0, { 9500, 0 })

      local start_time = vim.loop.hrtime()
      local match = occurrence:match_cursor({ wrap = true, direction = "forward" })
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_not_nil(match, "Should find a wrapped match")
      assert.is_true(elapsed < 100, "Wrapped search took too long: " .. elapsed .. "ms")
    end)

    it("navigates through many occurrences efficiently (forward)", function()
      bufnr = util.buffer(huge_content)
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor at the beginning
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local start_time = vim.loop.hrtime()
      local navigation_count = 0
      local max_navigations = 200 -- Realistic: user navigating through ~200 matches in a session

      for i = 1, max_navigations do
        local match = occurrence:match_cursor({ direction = "forward", wrap = true })
        if not match then
          break
        end
        navigation_count = navigation_count + 1
      end

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(navigation_count > 0, "Should find at least some matches")
      assert.is_true(
        elapsed < 200,
        "Navigating through " .. navigation_count .. " occurrences took too long: " .. elapsed
      )
    end)

    it("navigates through many occurrences efficiently (backward)", function()
      bufnr = util.buffer(huge_content)
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Position cursor near the end
      vim.api.nvim_win_set_cursor(0, { 9999, 0 })

      local start_time = vim.loop.hrtime()
      local navigation_count = 0
      local max_navigations = 200 -- Realistic: user navigating backward through ~200 matches

      for i = 1, max_navigations do
        local match = occurrence:match_cursor({ direction = "backward", wrap = true })
        if not match then
          break
        end
        navigation_count = navigation_count + 1
      end

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(navigation_count > 0, "Should find at least some matches")
      assert.is_true(
        elapsed < 200,
        "Navigating backward through " .. navigation_count .. " occurrences took too long: " .. elapsed
      )
    end)

    it("navigates through marked occurrences efficiently", function()
      bufnr = util.buffer(huge_content)
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Mark every 10th occurrence to simulate selective marking
      local mark_count = 0
      for match in occurrence:matches() do
        mark_count = mark_count + 1
        if mark_count % 10 == 0 then
          occurrence.extmarks:mark(match)
        end
      end

      -- Position cursor at the beginning
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local start_time = vim.loop.hrtime()
      local navigation_count = 0
      local max_navigations = 100 -- Realistic: navigating through ~100 marked occurrences

      for i = 1, max_navigations do
        local match = occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
        if not match then
          break
        end
        navigation_count = navigation_count + 1
      end

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(navigation_count > 0, "Should find at least some marked matches")
      assert.is_true(
        elapsed < 500,
        "Navigating through " .. navigation_count .. " marked occurrences took too long: " .. elapsed
      )
    end)

    it("handles alternating forward/backward navigation of both marked and unmarked occurrences efficiently", function()
      bufnr = util.buffer(huge_content)
      vim.api.nvim_set_current_buf(bufnr)
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Mark every 10th occurrence to simulate selective marking
      local mark_count = 0
      for match in occurrence:matches() do
        mark_count = mark_count + 1
        if mark_count % 10 == 0 then
          occurrence.extmarks:mark(match)
        end
      end

      -- Position cursor in the middle
      vim.api.nvim_win_set_cursor(0, { 5000, 0 })

      local start_time = vim.loop.hrtime()
      local navigation_count = 0
      local max_navigations = 200 -- Realistic: alternating direction ~200 times

      for i = 1, max_navigations do
        local direction = (i % 2 == 0) and "forward" or "backward"
        local marked = (i % 3 == 0) -- Every third navigation uses marked occurrences
        local match = occurrence:match_cursor({ direction = direction, wrap = true, marked = marked })
        if not match then
          break
        end
        navigation_count = navigation_count + 1
      end

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(navigation_count > 0, "Should find at least some matches")
      assert.is_true(
        elapsed < 300,
        "Alternating navigation through " .. navigation_count .. " occurrences took too long: " .. elapsed
      )
    end)
  end)

  describe("Range Operations Performance", function()
    it("processes large ranges efficiently", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")

      local large_range = Range.new(Location.new(0, 0), Location.new(5000, 0))

      local start_time = vim.loop.hrtime()
      local has_matches = occurrence:has_matches(large_range)
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(has_matches, "Should find matches in large range")
      assert.is_true(elapsed < 200, "Large range processing took too long: " .. elapsed .. "ms")
    end)

    it("marks within ranges efficiently", function()
      bufnr = util.buffer(huge_content)
      local occurrence = Occurrence.get(bufnr, "foo")

      local range = Range.new(Location.new(1000, 0), Location.new(2000, 0))

      local start_time = vim.loop.hrtime()
      local marked = occurrence:mark(range)
      local elapsed = (vim.loop.hrtime() - start_time) / 1e6

      assert.is_true(marked, "Should mark occurrences in range")
      assert.is_true(elapsed < 300, "Range marking took too long: " .. elapsed .. "ms")
    end)
  end)

  describe("Stress Tests", function()
    it("handles rapid occurrence creation and disposal", function()
      bufnr = util.buffer(large_content)
      local start_time = vim.loop.hrtime()

      for i = 1, 10 do
        local occurrence = Occurrence.get(bufnr, "content")
        occurrence:mark()
        occurrence:dispose()
      end

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6
      assert.is_true(elapsed < 1000, "Rapid creation/disposal (10 iterations) took too long: " .. elapsed .. "ms")
    end)

    it("handles concurrent buffer operations", function()
      -- Simulate concurrent operations on multiple buffers
      local buffers = {}
      local occurrences = {}

      local start_time = vim.loop.hrtime()

      -- Create multiple buffers with occurrences
      for i = 1, 10 do
        local buf = util.buffer(large_content)
        local occ = Occurrence.get(buf, "pattern_" .. (i % 5))
        table.insert(buffers, buf)
        table.insert(occurrences, occ)
      end

      -- Perform operations on all (avoid match_cursor which requires current buffer)
      for i, occ in ipairs(occurrences) do
        -- Switch to the buffer for this occurrence
        vim.api.nvim_set_current_buf(buffers[i])

        if i % 3 == 0 then
          occ:mark()
        end
        if i % 5 == 0 then
          -- Only call match_cursor when buffer is current
          local match = occ:match_cursor()
          if match then
            occ:mark(match)
          end
        end
      end

      -- Clean up
      for _, occ in ipairs(occurrences) do
        occ:dispose()
      end
      for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end

      local elapsed = (vim.loop.hrtime() - start_time) / 1e6
      assert.is_true(elapsed < 2000, "Concurrent operations took too long: " .. elapsed .. "ms")
    end)
  end)

  describe("Memory Usage Tests", function()
    it("maintains reasonable memory usage with many patterns", function()
      bufnr = util.buffer(large_content)

      local occurrence, count
      local memory_delta = measure_memory(function()
        occurrence = Occurrence.get(bufnr)

        -- Add many patterns
        for i = 1, 10 do
          occurrence:add_pattern("pattern_" .. i, "word")
        end

        -- Mark occurrences for all patterns
        occurrence:mark()
      end)

      local memory_delta2 = measure_memory(function()
        -- Cleanup
        occurrence:dispose()
      end)

      -- Should have increased memory usage
      assert.is_true(memory_delta > 0, "Memory measurement failed")
      -- Should not use more than 1MB for 100 patterns
      assert.is_true(memory_delta < 1024, "Many patterns used too much memory: " .. memory_delta .. "KB")
      -- Disposal should free some memory
      assert.is_true(memory_delta2 < 0, "Disposal did not free enough memory: " .. memory_delta2 .. "KB")
    end)

    it("occurrence creation and disposal cycles don't leak memory", function()
      bufnr = util.buffer(large_content)

      local memory_delta = measure_memory(function()
        -- Create and dispose many occurrences (similar to old "Memory Management Performance" test)
        for i = 1, 100 do
          local occurrence = Occurrence.get(bufnr, "pattern_" .. (i % 10))
          occurrence:dispose()
        end
      end)

      -- Should have minimal memory growth after disposal
      assert.is_true(memory_delta < 64, "Occurrence creation/disposal cycles leaked memory: " .. memory_delta .. "KB")
    end)

    it("occurrence creation with marking doesn't leak memory", function()
      bufnr = util.buffer(large_content)

      local memory_delta = measure_memory(function()
        -- Create and dispose many occurrences with marking
        for i = 1, 10 do
          local occurrence = Occurrence.get(bufnr, "content")
          occurrence:mark()
          occurrence:dispose()
        end
      end)

      local memory_delta2 = measure_memory(function()
        -- Create and dispose many occurrences with marking
        for i = 1, 10 do
          local occurrence = Occurrence.get(bufnr, "content")
          occurrence:mark()
          occurrence:dispose()
        end
      end)

      -- Should have minimal memory growth after disposal
      assert.is_true(memory_delta < 256, "Occurrence creation with marking leaked memory: " .. memory_delta .. "KB")
      assert.is_true(
        memory_delta2 < 64,
        "Second occurrence creation with marking leaked memory: " .. memory_delta2 .. "KB"
      )
    end)

    it("Occurrence cleanup doesn't leak memory", function()
      local memory_delta = measure_memory(function()
        local buffers = {}

        -- Create multiple buffers and occurrences (from old "Memory Management Performance" test)
        for i = 1, 50 do
          local buf = util.buffer({ "test content line " .. i, "another line with pattern" })
          table.insert(buffers, buf)
          local occurrence = Occurrence.get(buf, "pattern")
          occurrence:mark()
        end

        -- Clean up all buffers
        for _, buf in ipairs(buffers) do
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end)

      -- Should have minimal memory growth after cleanup
      assert.is_true(memory_delta < 256, "Buffer state cleanup leaked memory: " .. memory_delta .. "KB")
    end)

    it("extmarks don't cause significant memory growth", function()
      bufnr = util.buffer(huge_content)

      local memory_delta = measure_memory(function()
        local occurrence = Occurrence.get(bufnr, "foo")

        -- Mark all occurrences (should be thousands)
        occurrence:mark()

        -- Unmark all
        occurrence:unmark()

        occurrence:dispose()
      end)

      -- Extmark operations should not cause significant permanent memory growth
      assert.is_true(memory_delta < 512, "Extmark operations used excessive memory: " .. memory_delta .. "KB")
    end)

    it("occurrence cache has reasonable memory footprint", function()
      local memory_delta = measure_memory(function()
        local buffers = {}

        -- Create many buffer states
        for i = 1, 100 do
          local buf = util.buffer({ "test line " .. i })
          table.insert(buffers, buf)
          local state = Occurrence.get(buf)
          state:add_pattern("test_" .. i, "word")
        end

        -- Clean up explicitly
        for _, buf in ipairs(buffers) do
          Occurrence.del(buf)
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end)

      -- 100 buffer states should not use excessive memory
      assert.is_true(memory_delta < 64, "Occurrence cache used too much memory: " .. memory_delta .. "KB")
    end)

    it("large buffer processing has bounded memory usage", function()
      local memory_delta = measure_memory(function()
        local temp_buf = util.buffer(huge_content) -- 10k lines
        local occurrence = Occurrence.get(temp_buf, "foo")

        -- Process all matches
        local count = 0
        for _ in occurrence:matches() do
          count = count + 1
        end

        assert.is_true(count > 0, "Should find matches in large buffer")

        occurrence:dispose()
        if vim.api.nvim_buf_is_valid(temp_buf) then
          vim.api.nvim_buf_delete(temp_buf, { force = true })
        end
      end)

      -- Processing 10k lines should have reasonable memory usage
      assert.is_true(memory_delta < 256, "Large buffer processing used excessive memory: " .. memory_delta .. "KB")
    end)

    it("memory usage scales linearly with buffer size", function()
      -- Test with different buffer sizes
      local sizes = { 100, 500, 1000 }
      local memory_usage = {}

      for _, size in ipairs(sizes) do
        local test_content = {}
        for i = 1, size do
          table.insert(test_content, "line " .. i .. " with test pattern")
        end

        local memory_delta = measure_memory(function()
          local temp_buf = util.buffer(test_content)
          local occurrence = Occurrence.get(temp_buf, "pattern")
          occurrence:has_matches()
          occurrence:dispose()
          if vim.api.nvim_buf_is_valid(temp_buf) then
            vim.api.nvim_buf_delete(temp_buf, { force = true })
          end
        end)

        memory_usage[size] = memory_delta
      end

      -- Memory usage should scale reasonably (not exponentially)
      -- 10x size increase should not cause significant memory increase
      local ratio = memory_usage[1000] / math.max(memory_usage[100], 1)
      assert.is_true(ratio < 2, "Memory usage scales poorly: " .. ratio .. "x increase for 10x buffer size")
    end)
  end)
end)
