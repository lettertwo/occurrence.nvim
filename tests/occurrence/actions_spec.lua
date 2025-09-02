local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")
local util = require("tests.util")

local actions = require("occurrence.actions")
local Occurrence = require("occurrence.Occurrence")

describe("actions", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.fn.setreg("/", "")
    vim.v.hlsearch = 0
    bufnr = nil
  end)

  describe("find_cursor_word", function()
    it("finds occurrences of word under cursor", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, nil, {})
      actions.find_cursor_word(occurrence)

      assert.is_true(occurrence:has_matches())

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count) -- 2 occurrences of 'foo'
    end)
  end)

  describe("find_visual_subword", function()
    it("finds occurrences of visually selected text", function()
      bufnr = util.buffer("foo bar baz foo")
      -- Position cursor and create visual selection
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- Position at 'bar'
      vim.cmd("normal! viw") -- Select the word 'bar'

      local occurrence = Occurrence.new(bufnr, nil, {})
      actions.find_visual_subword(occurrence)

      assert.is_true(occurrence:has_matches())

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(1, match_count) -- 1 occurrence of 'bar'
    end)
  end)

  describe("find_last_search", function()
    it("finds occurrences using last search pattern", function()
      bufnr = util.buffer("foo bar baz foo")
      vim.fn.setreg("/", "foo")

      local occurrence = Occurrence.new(bufnr, nil, {})
      actions.find_last_search(occurrence)

      assert.is_true(occurrence:has_matches())

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count)
    end)

    it("warns when no search pattern available", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      vim.fn.setreg("/", "")

      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, nil, {})

      actions.find_last_search(occurrence)

      assert
        .spy(vim.notify)
        .was_called_with(match.is_match("No search pattern available"), vim.log.levels.WARN, match._)
      assert.is_false(occurrence:has_matches())

      -- restore original notify
      vim.notify = original_notify
    end)
  end)

  describe("find_active_search_or_cursor_word", function()
    it("uses cursor word when hlsearch is disabled", function()
      vim.v.hlsearch = 0
      vim.fn.setreg("/", "bar")
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.new(bufnr, nil, {})
      actions.find_active_search_or_cursor_word(occurrence)

      assert.is_true(occurrence:has_matches())

      local match_count = #vim.iter(occurrence:matches()):totable()
      assert.equals(2, match_count) -- Should find 'foo' occurrences
    end)
  end)

  describe("marking actions", function()
    describe("mark_all", function()
      it("marks all occurrences", function()
        bufnr = util.buffer("foo bar baz foo")
        local occurrence = Occurrence.new(bufnr, "foo", {})
        actions.mark_all(occurrence)

        local marked_count = #vim.iter(occurrence:marks()):totable()
        assert.equals(2, marked_count) -- All 2 'foo' occurrences
      end)
    end)

    describe("unmark_all", function()
      it("unmarks all occurrences", function()
        bufnr = util.buffer("foo bar baz foo")
        local occurrence = Occurrence.new(bufnr, "foo", {})
        actions.mark_all(occurrence)

        -- Verify they are marked
        local marked_count = #vim.iter(occurrence:marks()):totable()
        assert.equals(2, marked_count)

        -- Then unmark all
        actions.unmark_all(occurrence)

        marked_count = #vim.iter(occurrence:marks()):totable()
        assert.equals(0, marked_count)
      end)
    end)

    describe("mark", function()
      it("marks occurrence at cursor position", function()
        bufnr = util.buffer("foo bar baz foo")
        local occurrence = Occurrence.new(bufnr, "foo", {})

        actions.mark(occurrence)

        local marked_count = #vim.iter(occurrence:marks()):totable()
        assert.equals(1, marked_count)

        -- Mark again at same position should not increase count
        actions.mark(occurrence)
        marked_count = #vim.iter(occurrence:marks()):totable()
        assert.equals(1, marked_count)

        -- Move cursor to second 'foo' and mark
        vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- Position at second 'foo'
        actions.mark(occurrence)
        marked_count = #vim.iter(occurrence:marks()):totable()
        assert.equals(2, marked_count)
      end)
    end)

    describe("navigation", function()
      it("goto_next moves cursor to next occurrence", function()
        bufnr = util.buffer("foo bar baz foo")
        local occurrence = Occurrence.new(bufnr, "foo", {})

        -- Should move to second 'foo' at position (1, 12)
        actions.goto_next(occurrence)
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0))

        -- Calling again should wrap around to first 'foo'
        actions.goto_next(occurrence)
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      end)

      it("goto_previous moves cursor to previous occurrence", function()
        bufnr = util.buffer("foo bar baz foo")
        local occurrence = Occurrence.new(bufnr, "foo", {})
        vim.api.nvim_win_set_cursor(0, { 1, 12 }) -- Start at second 'foo' (0-indexed)
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0))

        -- Should move back to first 'foo' at position (1, 0)
        actions.goto_previous(occurrence)
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

        -- Calling again should wrap around to second 'foo'
        actions.goto_previous(occurrence)
        assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0))
      end)
    end)

    it("mark_cursor_word finds and marks all occurrences", function()
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.new(bufnr, nil, {})
      assert.is_false(occurrence:has_matches())

      actions.mark_cursor_word(occurrence)
      assert.is_true(occurrence:has_matches())

      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count) -- All 'foo' occurrences marked
    end)

    it("mark_cursor_word_or_toggle_mark should toggle existing occurrence", function()
      bufnr = util.buffer("foo bar baz foo")

      -- Create occurrence with pattern already set
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- First call should toggle mark (mark the current occurrence)
      actions.mark_cursor_word_or_toggle_mark(occurrence)

      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(1, marked_count) -- Should mark just the one at cursor

      -- Second call should toggle (unmark)
      actions.mark_cursor_word_or_toggle_mark(occurrence)

      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(0, marked_count) -- Should unmark the one at cursor
    end)

    it("mark_cursor_word_or_toggle_mark should add new cursor word marks", function()
      bufnr = util.buffer("foo bar baz foo bar")

      local occurrence = Occurrence.new(bufnr, nil, {})
      assert.is_false(occurrence:has_matches())
      actions.mark_cursor_word_or_toggle_mark(occurrence)
      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count) -- All 'foo' occurrences marked

      -- Should find and mark all occurrences of 'bar'
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- Position at 'bar'
      actions.mark_cursor_word_or_toggle_mark(occurrence)
      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(4, marked_count) -- All 'foo' and 'bar' occurrences marked
    end)

    it("mark_visual_subword finds and marks all occurrences of selection", function()
      bufnr = util.buffer("foo bar baz foo bar")
      vim.api.nvim_win_set_cursor(0, { 1, 5 }) -- Position at 'bar'
      vim.cmd("normal! viw") -- Select the word 'bar'

      local occurrence = Occurrence.new(bufnr, nil, {})
      assert.is_false(occurrence:has_matches())

      actions.mark_visual_subword(occurrence)
      assert.is_true(occurrence:has_matches())

      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count) -- All 'bar' occurrences marked
    end)

    it("mark_last_search finds and marks all occurrences of last search", function()
      bufnr = util.buffer("foo bar baz foo")
      vim.fn.setreg("/", "foo")

      local occurrence = Occurrence.new(bufnr, nil, {})
      assert.is_false(occurrence:has_matches())

      actions.mark_last_search(occurrence)
      assert.is_true(occurrence:has_matches())

      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count) -- All 'foo' occurrences marked
    end)

    it("mark_active_search_or_cursor_word uses cursor word when hlsearch is disabled", function()
      vim.v.hlsearch = 0
      vim.fn.setreg("/", "bar")
      bufnr = util.buffer("foo bar baz foo")

      local occurrence = Occurrence.new(bufnr, nil, {})
      assert.is_false(occurrence:has_matches())

      actions.mark_active_search_or_cursor_word(occurrence)
      assert.is_true(occurrence:has_matches())

      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count) -- All 'foo' occurrences marked
    end)
  end)

  describe("activation", function()
    it("warns when no matches found", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)
      local occurrence = Occurrence.new(bufnr, "nonexistent", {})

      actions.activate(occurrence, {})

      assert.spy(vim.notify).was_called_with(match.is_match("No matches found"), vim.log.levels.WARN, match._)

      -- Clean up
      actions.deactivate(occurrence)

      -- restore original notify
      vim.notify = original_notify
    end)

    it("succeeds when matches are found", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      actions.activate(occurrence, {})

      assert.spy(vim.notify).was_not_called()

      -- Clean up
      actions.deactivate(occurrence)

      -- restore original notify
      vim.notify = original_notify
    end)
  end)
end)
