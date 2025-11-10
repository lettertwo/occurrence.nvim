local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")
local util = require("tests.util")

local api = require("occurrence.api")
local Config = require("occurrence.Config")
local Occurrence = require("occurrence.Occurrence")

describe("api", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.fn.setreg("/", "")
    vim.v.hlsearch = 0
    bufnr = nil
  end)

  describe("word", function()
    it("finds and marks all occurrences of word under cursor", function()
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.get(bufnr)

      api.word.callback(occurrence, Config.new())
      assert.is_true(occurrence:has_matches(), "Should have matches after word")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count, "Should find 2 'foo' occurrences")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 'foo' occurrences")
    end)

    it("should only mark the new cursor word", function()
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.get(bufnr, "foo", "word")
      assert.is_true(occurrence:has_matches(), "Should have matches initially")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count, "Should have 2 'foo' occurrences initially")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(0, marked_count, "Should have 0 'foo' occurrences marked initially")

      -- Move cursor to 'bar' and mark
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- Position at 'bar'
      api.word.callback(occurrence, Config.new())

      assert.is_true(occurrence:has_matches(), "Should still have matches after word")
      match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(3, match_count, "Should find 1 additional 'bar' occurrence")

      -- Check that only 'bar' occurrences are marked
      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should haveo only 1 'bar' occurrence marked")
    end)
  end)

  describe("selection", function()
    it("finds and marks all occurrences of selection", function()
      bufnr = util.buffer("foo bar baz foo bar")
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- Position at 'bar'
      vim.cmd("normal! viw") -- Select the word 'bar'

      local occurrence = Occurrence.get(bufnr)

      api.selection.callback(occurrence, Config.new())
      assert.is_true(occurrence:has_matches(), "Should have matches after selection")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count, "Should find 2 'bar' occurrences")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 'bar' occurrences")
    end)
  end)

  describe("pattern", function()
    it("finds and marks all occurrences of last search", function()
      bufnr = util.buffer("foo bar baz foo")
      vim.fn.setreg("/", [[\woo]])

      local occurrence = Occurrence.get(bufnr)

      api.pattern.callback(occurrence, Config.new())
      assert.is_true(occurrence:has_matches(), "Should have matches after pattern")
      assert.is_same({ [[\woo]] }, occurrence.patterns, "Should use '\\woo' search pattern")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count, "Should find 2 '\\woo' occurrences")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 'foo' occurrences")
    end)

    it("warns when no search pattern available", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      vim.fn.setreg("/", "")

      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.get(bufnr)

      api.pattern.callback(occurrence, Config.new())

      assert
        .spy(vim.notify)
        .was_called_with(match.is_match("No search pattern available"), vim.log.levels.WARN, match._)
      assert.is_false(occurrence:has_matches(), "Should have no matches when no search pattern")

      -- restore original notify
      vim.notify = original_notify
    end)
  end)

  describe("current", function()
    it("it uses selection when active", function()
      vim.v.hlsearch = 1
      vim.fn.setreg("/", "bar")
      bufnr = util.buffer("foo bar baz foo bar")
      vim.api.nvim_win_set_cursor(0, { 1, 9 }) -- Position at 'baz'
      vim.cmd("normal! viw") -- Select the word 'baz'

      local occurrence = Occurrence.get(bufnr)
      assert.is_false(occurrence:has_matches())

      api.current.callback(occurrence, Config.new())
      assert.is_true(occurrence:has_matches(), "Should have matches after current")
      assert.is_same({ [[\V\Cbaz]] }, occurrence.patterns, "Should use escaped 'baz' selection as pattern")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(1, match_count, "Should find 1 'baz' occurrence")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should mark 1 'baz' occurrence")
    end)

    it("uses search pattern when hlsearch is enabled", function()
      vim.v.hlsearch = 1
      vim.fn.setreg("/", "bar")
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.get(bufnr)
      api.current.callback(occurrence, Config.new())

      assert.is_true(occurrence:has_matches(), "Should have matches after current")
      assert.is_same({ "bar" }, occurrence.patterns, "Should use 'bar' search pattern")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(1, match_count, "Should find 1 'bar' occurrence")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should mark 1 'bar' occurrence")
    end)

    it("uses cursor word when hlsearch is disabled", function()
      vim.v.hlsearch = 0
      vim.fn.setreg("/", "bar")
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.get(bufnr)

      api.current.callback(occurrence, Config.new())
      assert.is_true(occurrence:has_matches(), "Should have matches after current")
      assert.is_same({ [[\V\C\<foo\>]] }, occurrence.patterns, "Should use escaped '<foo>' cursor word as pattern")

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count, "Should find 2 'foo' occurrences")

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 'foo' occurrences")
    end)
  end)

  describe("mark_all", function()
    it("marks all occurrences", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:add_pattern([[ba\w]])
      api.mark_all.callback(occurrence, Config.new())

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(4, marked_count, "Should mark 2 'foo' and 2 ba\\w occurrences")
    end)
  end)

  describe("unmark_all", function()
    it("unmarks all occurrences", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:add_pattern([[ba\w]])
      api.mark_all.callback(occurrence, Config.new())

      -- Verify they are marked
      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(4, marked_count, "Should mark 4 occurrences")

      -- Then unmark all
      api.unmark_all.callback(occurrence, Config.new())

      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(0, marked_count, "Should unmark all occurrences")
    end)
  end)

  describe("mark", function()
    it("marks occurrence at cursor position", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      api.mark.callback(occurrence, Config.new())

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should mark 1 occurrence at cursor")

      -- Mark again at same position should not increase count
      api.mark.callback(occurrence, Config.new())
      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should still have 1 occurrence marked")

      -- Move cursor to second 'foo' and mark
      vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- Position at second 'foo'
      api.mark.callback(occurrence, Config.new())
      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 occurrences total")
    end)
  end)

  describe("unmark", function()
    it("unmarks occurrence at cursor position", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark both 'foo' occurrences
      api.mark_all.callback(occurrence, Config.new())
      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 occurrences initially")

      -- Unmark first 'foo'
      api.unmark.callback(occurrence, Config.new())
      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should unmark 1 occurrence at cursor")

      -- Move to second 'foo' and unmark
      vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- Position at second 'foo'
      api.unmark.callback(occurrence, Config.new())
      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(0, marked_count, "Should unmark all occurrences")
    end)

    it("unmarks the nearest occurrence if no occurrence at cursor", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark both 'foo' occurrences
      api.mark_all.callback(occurrence, Config.new())
      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should mark 2 occurrences initially")

      -- Move cursor to 'bar' where no 'foo' exists
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- Position at 'bar'
      api.unmark.callback(occurrence, Config.new())

      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should unmark 1 occurrence nearest to cursor")
    end)
  end)

  describe("toggle", function()
    it("should toggle existing occurrence", function()
      bufnr = util.buffer("foo bar baz foo")

      -- Create occurrence with pattern already set
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- First call should toggle mark (mark the current occurrence)
      api.toggle.callback(occurrence, Config.new())

      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(1, marked_count, "Should mark the one at cursor")

      -- Second call should toggle (unmark)
      api.toggle.callback(occurrence, Config.new())

      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(0, marked_count, "Should unmark the one at cursor")
    end)

    it("should add new cursor word marks", function()
      bufnr = util.buffer("foo bar baz foo bar")

      local occurrence = Occurrence.get(bufnr)
      assert.is_false(occurrence:has_matches())
      api.toggle.callback(occurrence, Config.new())
      local marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(2, marked_count, "Should find and mark both 'foo' occurrences")

      -- Should find and mark all occurrences of 'bar'
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- Position at 'bar'
      api.toggle.callback(occurrence, Config.new())
      marked_count = #vim.iter(occurrence.extmarks:iter()):totable()
      assert.equals(4, marked_count, "Should find and mark both 'bar' occurrences")
    end)
  end)

  describe("API annotations", function()
    it("type annotations exist for all exported API functions", function()
      -- Read the source file to check for annotations
      local source_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/lua/occurrence.lua"
      local file = io.open(source_path, "r")
      assert(file, "Could not open lua/occurrence.lua")
      local source = file:read("*a")
      file:close()

      -- Extract all @field annotations from @class occurrence
      local annotated_fields = {}
      local in_class = false
      for line in source:gmatch("[^\n]+") do
        if line:match("^%-%-%-%s*@class%s+occurrence%s*$") then
          in_class = true
        elseif in_class then
          -- Stop when we hit another annotation or code
          if line:match("^%-%-%-%s*@type%s+occurrence") or line:match("^local occurrence") then
            break
          end
          -- Extract field name from ---@field name ...
          local field = line:match("^%-%-%-%s*@field%s+(%S+)")
          if field then
            annotated_fields[field] = true
          end
        end
      end

      -- Check that all exported functions have @field annotations
      local missing = {}
      for name in pairs(api) do
        if not annotated_fields[name] then
          table.insert(missing, name)
        end
      end
      table.sort(missing)

      assert.same(
        {},
        missing,
        string.format(
          "Missing @field annotations in @class occurrence for: %s\n" .. "Add these annotations to lua/occurrence.lua",
          table.concat(missing, ", ")
        )
      )

      -- Check that there are no extra @field annotations
      local extra = {}
      for name in pairs(annotated_fields) do
        if not api[name] then
          table.insert(extra, name)
        end
      end
      table.sort(extra)

      assert.same(
        {},
        extra,
        string.format(
          "Extra @field annotations in @class occurrence that don't correspond to exported functions: %s\n"
            .. "Remove these annotations from lua/occurrence.lua or implement the functions",
          table.concat(extra, ", ")
        )
      )
    end)
  end)
end)
