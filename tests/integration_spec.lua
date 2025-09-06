local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")
local util = require("tests.util")

local actions = require("occurrence.actions")
local Occurrence = require("occurrence.Occurrence")

local NS = vim.api.nvim_create_namespace("Occurrence")

describe("integration tests", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.fn.setreg("/", "")
    vim.v.hlsearch = 0
    bufnr = nil
  end)

  describe("activate", function()
    it("warns when no matches found", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)
      local occurrence = Occurrence.new(bufnr, "nonexistent", {})

      actions.activate(occurrence, {})

      assert.spy(vim.notify).was_called_with(match.is_match("No matches found"), vim.log.levels.WARN, match._)

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

      -- restore original notify
      vim.notify = original_notify
    end)

    it("sets up keymaps for cancelling", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      actions.activate(occurrence)

      -- Check that a key is mapped in normal mode to deactivate
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local cancel_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Clear occurrence" then
          cancel_key = map.lhs
          break
        end
      end
      assert(cancel_key, "Cancel key should be mapped")

      -- Simulate pressing cancel key to trigger deactivation
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cancel_key, true, false, true), "mx", true)

      -- Verify keymap is removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      cancel_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Clear occurrence" then
          cancel_key = map.lhs
          break
        end
      end
      assert.is_nil(cancel_key, "Cancel key should be unmapped after deactivation")
    end)

    it("sets up keymaps for marking and unmarking", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      actions.activate(occurrence)

      -- Check that keys are mapped in normal mode to mark and unmark occurrences
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local mark_key = nil
      local unmark_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Mark occurrence" then
          mark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Unmark occurrence" then
          unmark_key = map.lhs
        end
      end
      assert(mark_key, "Mark key should be mapped")
      assert(unmark_key, "Unmark key should be mapped")

      -- Simulate pressing mark key to mark occurrence
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(mark_key, true, false, true), "mx", true)
      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(1, marked_count, "Occurrence at cursor should be marked")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 1, 0, 0 } }, marks) -- First "foo" marked

      -- Simulate pressing unmark key to unmark occurrence
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(unmark_key, true, false, true), "mx", true)
      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(0, marked_count, "No occurrences should be marked")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({}, marks) -- No marks

      -- Clean up
      actions.deactivate(occurrence)

      -- Verify keymaps are removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      mark_key = nil
      unmark_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Mark occurrence" then
          mark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Unmark occurrence" then
          unmark_key = map.lhs
        end
      end
      assert.is_nil(mark_key, "Mark key should be unmapped after deactivation")
      assert.is_nil(unmark_key, "Unmark key should be unmapped after deactivation")
    end)

    it("sets up keymaps for toggling marks", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      occurrence:mark()
      actions.activate(occurrence)

      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count, "Occurrence at cursor should be marked")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 1, 0, 0 }, { 2, 0, 12 } }, marks)

      -- Check that a key is mapped in normal mode to toggle mark
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Toggle occurrence mark" then
          toggle_key = map.lhs
          break
        end
      end
      assert(toggle_key, "Toggle mark key should be mapped")

      -- Simulate pressing toggle mark key to mark occurrence
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(toggle_key, true, false, true), "mx", true)

      -- Check that one occurrence is toggled
      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(1, marked_count, "Occurrence at cursor should be marked")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 2, 0, 12 } }, marks)

      -- Move to "bar" and toggle mark
      vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- Position at 'bar'
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(toggle_key, true, false, true), "mx", true)

      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(2, marked_count, "Occurrence at cursor should be marked")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 3, 0, 4 }, { 2, 0, 12 } }, marks)

      -- Clean up
      actions.unmark_all(occurrence)
      actions.deactivate(occurrence)

      -- Verify keymap is removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Toggle mark at cursor" then
          toggle_key = map.lhs
          break
        end
      end
      assert.is_nil(toggle_key, "Toggle mark key should be unmapped after deactivation")
    end)

    it("sets up keymaps for navigating occurrences", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      actions.activate(occurrence)

      -- Check that keys are mapped in normal mode to navigate
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local next_key = nil
      local prev_key = nil
      local next_marked_key = nil
      local prev_marked_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Next occurrence" then
          next_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Previous occurrence" then
          prev_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Next marked occurrence" then
          next_marked_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Previous marked occurrence" then
          prev_marked_key = map.lhs
        end
      end
      assert(next_key, "Next occurrence key should be mapped")
      assert(prev_key, "Previous occurrence key should be mapped")
      assert(next_marked_key, "Next marked occurrence key should be mapped")
      assert(prev_marked_key, "Previous marked occurrence key should be mapped")

      -- Simulate pressing next marked occurrence key (no marks yet, should do same as next occurrence)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to next occurrence")

      -- Simulate pressing next marked occurrence key (no marks yet, should do same as next occurrence)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should wrap to first occurrence")

      -- Simulate pressing next occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to next occurrence")

      -- Simulate pressing next occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should wrap to first occurrence")

      -- Simulate pressing previous marked occurrence key (no marks yet, should do same as previous occurrence)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to previous occurrence")

      -- Simulate pressing previous marked occurrence key (no marks yet, should do same as previous occurrence)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should wrap to last occurrence")

      -- Simulate pressing previous occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to previous occurrence")

      -- Simulate pressing previous occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should wrap to last occurrence")

      actions.mark(occurrence) -- Mark the current occurrence

      -- Simulate pressing next marked occurrence key (only one marked, should stay)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should remain at only marked occurrence")

      -- Simulate pressing previous marked occurrence key (only one marked, should stay)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should remain at only marked occurrence")

      -- Simulate pressing next occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should wrap to first occurrence")

      -- Mark current occurrence
      actions.mark(occurrence)

      -- Simulate pressing previous occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(prev_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to previous occurrence")

      -- Simulate pressing next marked occurrence key (to go to first marked occurrence)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to next marked occurrence")

      -- Simulate pressing next marked occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Cursor should move to next marked occurrence")

      -- Simulate pressing next marked occurrence key
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(next_marked_key, true, false, true), "mx", true)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Cursor should wrap to first marked occurrence")

      -- Clean up
      actions.unmark_all(occurrence)
      actions.deactivate(occurrence)

      -- Verify keymaps are removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      next_key = nil
      prev_key = nil
      next_marked_key = nil
      prev_marked_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Next occurrence" then
          next_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Previous occurrence" then
          prev_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Next marked occurrence" then
          next_marked_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Previous marked occurrence" then
          prev_marked_key = map.lhs
        end
      end
      assert.is_nil(next_key, "Next occurrence key should be unmapped after deactivation")
      assert.is_nil(prev_key, "Previous occurrence key should be unmapped after deactivation")
      assert.is_nil(next_marked_key, "Next marked occurrence key should be unmapped after deactivation")
      assert.is_nil(prev_marked_key, "Previous marked occurrence key should be unmapped after deactivation")
    end)

    it("sets up keymaps for visually narrowing occurrence marks", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "bar", {})

      actions.activate(occurrence)

      -- Check that keys are mapped in visual mode to narrow marks
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "x")
      local mark_key = nil
      local unmark_key = nil
      local toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Mark occurrences" then
          mark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Unmark occurrences" then
          unmark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Toggle occurrence marks" then
          toggle_key = map.lhs
        end
      end
      assert(mark_key, "Mark key should be mapped in visual mode")
      assert(unmark_key, "Unmark key should be mapped in visual mode")
      assert(toggle_key, "Toggle mark key should be mapped in visual mode")

      -- Simulate visual selection of "foo bar baz"
      vim.api.nvim_feedkeys("v3e", "mx", true)
      -- Simulate pressing mark key to mark occurrences in selection
      vim.api.nvim_feedkeys(mark_key, "mx", true)
      local marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(1, marked_count, "One occurrence should be marked in selection")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 1, 0, 4 } }, marks) -- First "foo" marked

      -- Simulate pressing unmark key to unmark occurrences in selection
      vim.api.nvim_feedkeys(unmark_key, "mx", true)
      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(0, marked_count, "No occurrences should be marked after unmarking")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({}, marks) -- No marks

      -- Simulate pressing toggle key to toggle marks in selection
      vim.api.nvim_feedkeys(toggle_key, "mx", true)
      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(1, marked_count, "One occurrence should be marked after toggling")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({ { 2, 0, 4 } }, marks) -- First "foo" marked

      -- Simulate pressing toggle key again to unmark in selection
      vim.api.nvim_feedkeys(toggle_key, "mx", true)
      marked_count = #vim.iter(occurrence:marks()):totable()
      assert.equals(0, marked_count, "No occurrences should be marked after toggling again")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, NS, 0, -1, {})
      assert.same({}, marks) -- No marks

      -- Clean up
      actions.unmark_all(occurrence)
      actions.deactivate(occurrence)

      -- Verify keymaps are removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "x")
      mark_key = nil
      unmark_key = nil
      toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Mark occurrences" then
          mark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Unmark occurrences" then
          unmark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == "Toggle occurrence marks" then
          toggle_key = map.lhs
        end
      end
      assert.is_nil(mark_key, "Mark key should be unmapped after deactivation")
      assert.is_nil(unmark_key, "Unmark key should be unmapped after deactivation")
      assert.is_nil(toggle_key, "Toggle mark key should be unmapped after deactivation")
    end)
  end)

  describe("deactivate", function()
    it("does not deactivate if marks are present", function()
      bufnr = util.buffer("foo bar baz foo")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      actions.activate(occurrence)

      occurrence:mark() -- Mark an occurrence to prevent deactivation

      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      actions.deactivate(occurrence)

      assert.spy(vim.notify).was_called_with(match.is_match("Occurrence still has marks"), vim.log.levels.WARN, match._)

      -- Check that keymap for cancelling still exists
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local cancel_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Clear occurrence" then
          cancel_key = map.lhs
          break
        end
      end
      assert(cancel_key, "Cancel key should still be mapped since marks are present")

      -- restore original notify
      vim.notify = original_notify
    end)
  end)
end)
