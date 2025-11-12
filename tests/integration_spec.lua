local assert = require("luassert")
local match = require("luassert.match")
local stub = require("luassert.stub")
local util = require("tests.util")

local builtins = require("occurrence.api")
local feedkeys = require("occurrence.feedkeys")
local plugin = require("occurrence")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

describe("integration tests", function()
  local bufnr
  local notify_stub

  before_each(function()
    -- stub out notify to avoid polluting test output
    notify_stub = stub(vim, "notify")
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.fn.setreg("/", "")
    vim.v.hlsearch = 0
    bufnr = nil
    plugin.reset()

    notify_stub:revert()
  end)

  describe("activate_occurrence_mode", function()
    it("warns when no matches found", function()
      -- Create buffer with a unique word that won't have multiple occurrences
      bufnr = util.buffer("unique_word_that_appears_only_once")

      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      vim.cmd([[silent! /nonexistent_pattern<CR>]]) -- Search for a pattern that won't match anything

      feedkeys("q") -- Simulate pressing the normal keymap to activate occurrence on the current word

      assert
        .spy(notify_stub)
        .was_called_with(match.is_match("No matches found"), vim.log.levels.WARN, { title = "Occurrence" })
    end)

    it("sets up keymaps for cancelling", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Should have 2 marks for 'foo'")

      -- Check that escape key is mapped to deactivate
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local cancel_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.deactivate.desc then
          cancel_key = map.lhs
          break
        end
      end
      assert(cancel_key, "Cancel key should be mapped")

      -- Simulate pressing cancel key to trigger deactivation
      feedkeys(cancel_key)

      -- Verify marks are cleared
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "Marks should be cleared after deactivation")

      -- Verify keymap is removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      cancel_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.deactivate.desc then
          cancel_key = map.lhs
          break
        end
      end
      assert.is_nil(cancel_key, "Cancel key should be unmapped after deactivation")
    end)

    it("sets up keymaps for marking and unmarking", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      -- Check that keys are mapped in normal mode to mark and unmark occurrences
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local mark_key = nil
      local unmark_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.mark.desc then
          mark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == builtins.unmark.desc then
          unmark_key = map.lhs
        end
      end
      assert(mark_key, "Mark key should be mapped")
      assert(unmark_key, "Unmark key should be mapped")

      -- Initially all occurrences should be marked (from activation)
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked initially")

      -- Simulate pressing unmark key to unmark occurrence at cursor
      feedkeys(unmark_key)
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "One occurrence should remain marked")
      assert.same({ { 2, 0, 12 } }, marks, "Second 'foo' should remain marked")

      -- Simulate pressing mark key to mark occurrence at cursor again
      feedkeys(mark_key)
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both occurrences should be marked again")

      -- Clean up by pressing escape
      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared after deactivation")

      -- Verify keymaps are removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      mark_key = nil
      unmark_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.mark.desc then
          mark_key = map.lhs
        elseif map.lhs ~= nil and map.desc == builtins.unmark.desc then
          unmark_key = map.lhs
        end
      end
      assert.is_nil(mark_key, "Mark key should be unmapped after deactivation")
      assert.is_nil(unmark_key, "Unmark key should be unmapped after deactivation")
    end)

    it("sets up keymaps for toggling marks", function()
      bufnr = util.buffer("foo bar baz foo")

      local normal_key = "q"
      plugin.setup({})
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all occurrences)
      feedkeys(normal_key)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Check that a key is mapped in normal mode to toggle mark
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.toggle.desc then
          toggle_key = map.lhs
          break
        end
      end
      assert(toggle_key, "Toggle mark key should be mapped")

      -- Simulate pressing toggle mark key to unmark occurrence at cursor
      feedkeys(toggle_key)

      -- Check that one occurrence is toggled off
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "One occurrence should remain marked")
      assert.same({ { 2, 0, 12 } }, marks, "Second 'foo' should remain marked")

      -- Move to "bar" and toggle mark (should add 'bar' to occurrences)
      feedkeys("w") -- Move to 'bar'
      feedkeys(toggle_key)

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Should have marks for remaining 'foo' and new 'bar'")

      -- Clean up by pressing escape
      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared after deactivation")

      -- Verify keymap is removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.toggle.desc then
          toggle_key = map.lhs
          break
        end
      end
      assert.is_nil(toggle_key, "Toggle mark key should be unmapped after deactivation")
    end)

    it("sets up keymaps for navigating occurrences", function()
      bufnr = util.buffer("foo bar baz foo")

      local normal_key = "q"
      plugin.setup({})
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (cursor at position 0)
      feedkeys(normal_key)

      -- Check that keys are mapped in normal mode to navigate
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local next_key = nil
      local prev_key = nil
      local next_marked_key = nil
      local prev_marked_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.match_next.desc then
          next_key = map.lhs
        elseif map.lhs ~= nil and map.desc == builtins.match_previous.desc then
          prev_key = map.lhs
        elseif map.lhs ~= nil and map.desc == builtins.next.desc then
          next_marked_key = map.lhs
        elseif map.lhs ~= nil and map.desc == builtins.previous.desc then
          prev_marked_key = map.lhs
        end
      end
      assert(next_key, "Next occurrence key should be mapped")
      assert(prev_key, "Previous occurrence key should be mapped")
      assert(next_marked_key, "Next marked occurrence key should be mapped")
      assert(prev_marked_key, "Previous marked occurrence key should be mapped")

      -- Test basic navigation between occurrences
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Should start at first 'foo'")

      -- Next occurrence should go to second 'foo'
      feedkeys(next_key)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Should move to second 'foo'")

      -- Next again should wrap to first 'foo'
      feedkeys(next_key)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Should wrap to first 'foo'")

      -- Previous should go to second 'foo'
      feedkeys(prev_key)
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Should move to second 'foo'")

      -- Test navigation with all marked (since we activated, all should be marked)
      feedkeys(next_marked_key)
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Should move to first marked 'foo'")

      -- Clean up
      feedkeys("<Esc>")

      -- Verify keymaps are removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      next_key = nil
      prev_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.match_next.desc then
          next_key = map.lhs
        elseif map.lhs ~= nil and map.desc == builtins.match_previous.desc then
          prev_key = map.lhs
        end
      end
      assert.is_nil(next_key, "Next occurrence key should be unmapped after deactivation")
      assert.is_nil(prev_key, "Previous occurrence key should be unmapped after deactivation")
    end)

    it("sets up keymaps for visually narrowing occurrence marks", function()
      bufnr = util.buffer("foo bar baz foo")

      local normal_key = "q"
      plugin.setup({})
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Move to 'bar' and activate occurrence
      feedkeys("w") -- Move to 'bar'
      feedkeys(normal_key)

      -- Verify bar occurrence is marked
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "Should have 1 mark for 'bar'")
      assert.same({ { 1, 0, 4 } }, marks, "'bar' should be marked at position 4")

      -- Check that keys are mapped in visual mode to narrow marks
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "x")
      local toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.toggle.desc then
          toggle_key = map.lhs
        end
      end
      assert(toggle_key, "Toggle mark key should be mapped in visual mode")

      -- Test visual selection to toggle marks within selection
      feedkeys("^v$") -- Select entire line
      feedkeys(toggle_key)

      -- Since 'bar' was marked and we toggled in selection, it should be unmarked
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "'bar' should be unmarked after visual toggle")

      -- Toggle again should mark it back
      feedkeys(toggle_key)
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "'bar' should be marked again after second toggle")

      -- Clean up
      feedkeys("<Esc>") -- Exit visual mode
      feedkeys("<Esc>") -- Deactivate occurrence

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared after deactivation")

      -- Verify keymaps are removed after deactivation
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "x")
      toggle_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == builtins.toggle.desc then
          toggle_key = map.lhs
        end
      end
      assert.is_nil(toggle_key, "Toggle mark key should be unmapped after deactivation")
    end)

    it("finds marks in visual selection", function()
      bufnr = util.buffer({ "no matches on this line", "foo bar baz foo" })

      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      feedkeys("j") -- Move to second line
      feedkeys("q") -- Activate occurrence (marks all 'foo')
      feedkeys("k") -- Move to first line
      feedkeys("Vj") -- Visually select both lines
      feedkeys("d") -- Simulate pressing delete to delete marked occurrences in selection

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("no matches on this line", lines[1], "First line should be unchanged")
      assert.equals(" bar baz ", lines[2], "Both 'foo' occurrences should be deleted from second line")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")

      feedkeys("dd") -- normal delete operator should work
      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ " bar baz " }, lines, "Buffer should only have one line")
    end)
  end)

  describe("deactivate", function()
    it("it clears previous patterns and marks", function()
      bufnr = util.buffer("foo bar baz foo")

      local normal_key = "q"
      plugin.setup({})
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- simulate pressing normal keymap to find 'foo'
      feedkeys(normal_key)
      assert.same(
        { { 1, 0, 0 }, { 2, 0, 12 } },
        vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {}),
        "Marks for 'foo' should be present"
      )

      -- Move to 'bar'
      feedkeys("w")
      -- simulate pressing normal keymap to find 'foo'
      feedkeys(normal_key)
      assert.same(
        { { 1, 0, 0 }, { 3, 0, 4 }, { 2, 0, 12 } },
        vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {}),
        "Marks for 'foo' and 'bar' should be present"
      )

      -- simulate pressing escape to exit any pending mappings
      feedkeys("<Esc>")
      assert.same(
        {},
        vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {}),
        "No marks should remain after deactivation"
      )

      -- Move to start of line
      feedkeys("^")
      -- simulate pressing normal keymap to find 'foo'
      feedkeys(normal_key)
      assert.same(
        { { 1, 0, 0 }, { 2, 0, 12 } },
        vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {}),
        "Only 'foo' marks should be present after re-marking cursor word"
      )

      -- simulate pressing escape to exit any pending mappings
      feedkeys("<Esc>")
      assert.same(
        {},
        vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {}),
        "No marks should remain after deactivation"
      )
    end)
  end)

  describe("modify_operator", function()
    it("warns when trying to modify unsupported operator", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        operators = { c = false },
      })
      vim.keymap.set("o", "q", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

      -- Enter change operator-pending mode, modify operator
      feedkeys("cq")

      vim.wait(0) -- The operator-modifier action is async.

      assert
        .spy(notify_stub)
        .was_called_with(match.is_match("Operator 'c' is not supported"), vim.log.levels.WARN, { title = "Occurrence" })

      -- There should be no marks since operator was unsupported.
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "No 'foo' occurrences should be marked")
    end)

    it("modifies operator supported via direct_api method", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        operators = {
          d = {
            desc = "Delete on marked occurrences",
            method = "direct_api",
            uses_register = true,
            modifies_text = true,
            replacement = function()
              return ""
            end,
          },
        },
      })
      vim.keymap.set("o", "q", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

      -- Enter delete operator-pending mode, modify operator
      feedkeys("dq")

      vim.wait(0) -- The operator-modifier action is async.

      -- Verify no changes have been made yet.
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("foo bar baz foo", lines[1], "No 'foo' occurrences should be deleted yet")

      -- Verify marks are created for all 'foo' occurrences
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Complete a motion to apply delete operator
      feedkeys("$")

      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(" bar baz ", lines[1], "Both 'foo' occurrences should be deleted")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")
    end)

    it("modifies operator supported via command method", function()
      bufnr = util.buffer({ "foo bar baz foo", "  foo indented" })

      plugin.setup({
        operators = {
          ["<"] = {
            desc = "Indent marked occurrences to the left",
            method = "command",
            uses_register = false,
            modifies_text = true,
          },
        },
      })
      vim.keymap.set("o", "q", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

      -- Enter left shift operator-pending mode, modify operator
      feedkeys("<q")

      vim.wait(0) -- The operator-modifier action is async.

      -- Verify no changes have been made yet.
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar baz foo", "  foo indented" }, lines, "No 'foo' occurrences should be indented yet")

      -- Verify marks are created for all 'foo' occurrences
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'foo' occurrences should be marked")

      -- Complete a motion to apply operator
      feedkeys("j")

      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar baz foo", "foo indented" }, lines, "Both 'foo' occurrences should be indented left")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")
    end)

    it("modifies operator supported via visual_feedkeys method", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        operators = {
          ["gU"] = {
            desc = "Make marked occurrences uppercase",
            method = "visual_feedkeys",
            uses_register = false,
            modifies_text = true,
          },
        },
      })
      vim.keymap.set("o", "q", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

      -- Enter tilde operator-pending mode, modify operator
      feedkeys("gUq")

      vim.wait(0) -- The operator-modifier action is async.

      -- Verify no changes have been made yet.
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("foo bar baz foo", lines[1], "No 'foo' occurrences should be modified yet")

      -- Verify marks are created for all 'foo' occurrences
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Complete a motion to apply operator
      feedkeys("$")

      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("FOO bar baz FOO", lines[1], "Both 'foo' occurrences should be uppercased")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")
    end)

    it("cancels operator modification if there are no marked occurrences", function()
      bufnr = util.buffer({ "", "foo bar baz foo" })

      plugin.setup({
        operators = {
          d = {
            desc = "Delete on marked occurrences",
            method = "direct_api",
            uses_register = true,
            modifies_text = true,
            replacement = function()
              return ""
            end,
          },
        },
      })
      vim.keymap.set("o", "q", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

      local listener = stub.new()

      local listener_id = vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "*",
        callback = function(...)
          listener(...)
        end,
      })

      -- Enter delete operator-pending mode, modify operator
      feedkeys("dq")

      vim.wait(0) -- The operator-modifier action is async.

      -- Verify no marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "No occurrences should be marked")

      -- Verify mode change events were triggered
      assert.spy(listener).was_called_at_least(2)
      -- should've been called first to enter operator-pending mode
      assert.is_same(listener.calls[1].vals[1], {
        buf = bufnr,
        event = "ModeChanged",
        file = "",
        id = listener_id,
        match = "n:no",
      })

      -- should've been called last to enter normal mode
      assert.is_same(listener.calls[#listener.calls].vals[1], {
        buf = bufnr,
        event = "ModeChanged",
        file = "",
        id = listener_id,
        match = "no:n",
      })

      listener:clear()

      feedkeys("<Esc>") -- This should have no effect since operator modification was already cancelled.
      assert.spy(listener).was_not_called()

      vim.api.nvim_del_autocmd(listener_id)
    end)

    it("cancels operator modification on escape", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        operators = {
          d = {
            desc = "Delete on marked occurrences",
            method = "direct_api",
            uses_register = true,
            modifies_text = true,
            replacement = function()
              return ""
            end,
          },
        },
      })
      vim.keymap.set("o", "q", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

      local listener = stub.new()

      local listener_id = vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "*",
        callback = function(...)
          listener(...)
        end,
      })

      -- Enter delete operator-pending mode, modify operator
      feedkeys("dq")

      vim.wait(0) -- The operator-modifier action is async.

      -- Verify marks are created for all 'foo' occurrences
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Simulate pressing escape to cancel operator modification
      feedkeys("<Esc>")

      vim.wait(0) -- The operator-modifier action is async.

      -- Verify marks are cleared
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after cancelling operator modification")

      -- Verify no changes have been made to buffer
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("foo bar baz foo", lines[1], "No 'foo' occurrences should be deleted")

      -- Verify mode change events were triggered
      assert.spy(listener).was_called_at_least(2)
      -- should've been called first to enter operator-pending mode
      assert.is_same(listener.calls[1].vals[1], {
        buf = bufnr,
        event = "ModeChanged",
        file = "",
        id = listener_id,
        match = "n:no",
      })

      -- should've been called last to enter normal mode
      assert.is_same(listener.calls[#listener.calls].vals[1], {
        buf = bufnr,
        event = "ModeChanged",
        file = "",
        id = listener_id,
        match = "no:n",
      })

      listener:clear()
      feedkeys("<Esc>") -- This should have no effect since operator modification was already cancelled.
      assert.spy(listener).was_not_called()

      vim.api.nvim_del_autocmd(listener_id)
    end)
  end)

  describe("keymaps config", function()
    it("uses custom keymaps when default_keymaps = false", function()
      bufnr = util.buffer("foo bar baz foo")

      local custom_keymap_called = false
      plugin.setup({
        default_keymaps = false,
        keymaps = {
          ["<Tab>"] = "next",
          ["x"] = {
            callback = function(occ, config)
              custom_keymap_called = true
              occ:dispose()
            end,
            desc = "Custom exit action",
          },
        },
      })
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Check that custom keymap <Tab> is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local tab_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs == "<Tab>" then
          tab_key = map.lhs
          break
        end
      end
      assert.equals("<Tab>", tab_key, "<Tab> should be mapped to next")

      -- Check that default keymaps are NOT mapped (e.g., 'n')
      local n_key_found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "n" and map.desc == builtins.next.desc then
          n_key_found = true
          break
        end
      end
      assert.is_false(n_key_found, "'n' should not be mapped when default_keymaps = false")

      -- Test custom callback keymap
      feedkeys("x")
      assert.is_true(custom_keymap_called, "Custom callback should have been called")

      -- Verify marks are cleared
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "Marks should be cleared after custom exit action")
    end)

    it("allows disabling specific default keymaps", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        keymaps = {
          ["n"] = false, -- Disable default 'n' keymap
        },
      })
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      -- Check that 'n' is NOT mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local n_key_found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "n" and map.desc == builtins.next.desc then
          n_key_found = true
          break
        end
      end
      assert.is_false(n_key_found, "'n' should not be mapped when explicitly disabled")

      -- Check that other default keymaps are still mapped (e.g., 'N')
      local n_prev_found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "N" and map.desc == builtins.previous.desc then
          n_prev_found = true
          break
        end
      end
      assert.is_true(n_prev_found, "'N' should still be mapped")

      -- Clean up
      feedkeys("<Esc>")
    end)

    it("supports aliasing keymaps to different actions", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        keymaps = {
          ["<C-n>"] = "next", -- Alias <C-n> to next action
        },
      })
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      -- Check that <C-n> is mapped to next
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local ctrl_n_found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "<C-N>" or map.lhs == "<C-n>" then
          ctrl_n_found = true
          assert.equals(builtins.next.desc, map.desc)
          break
        end
      end
      assert.is_true(ctrl_n_found, "<C-n> should be mapped to next action")

      -- Clean up
      feedkeys("<Esc>")
    end)

    it("supports custom KeymapConfig with callback", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        keymaps = {
          ["z"] = {
            callback = function(occurrence)
              occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
            end,
            desc = "Custom next binding",
          },
        },
      })
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      -- Check that 'z' is mapped with custom desc
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local z_key_found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "z" and map.desc == "Custom next binding" then
          z_key_found = true
          break
        end
      end
      assert.is_true(z_key_found, "'z' should be mapped with custom description")

      -- Test that it actually navigates
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0), "Should start at first 'foo'")
      feedkeys("z") -- Use custom mapped key
      assert.same({ 1, 12 }, vim.api.nvim_win_get_cursor(0), "Should move to second 'foo'")

      -- Clean up
      feedkeys("<Esc>")
    end)

    it("on_activate callback works alongside keymaps config", function()
      bufnr = util.buffer("foo bar baz foo")

      local on_activate_called = false
      local custom_keymap_set = false

      plugin.setup({
        keymaps = {
          ["<Tab>"] = "next",
        },
        on_activate = function(map)
          on_activate_called = true
          map("n", "z", function()
            custom_keymap_set = true
          end, { desc = "Custom on_activate keymap" })
        end,
      })
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo'
      feedkeys("q")

      assert.is_true(on_activate_called, "on_activate callback should have been called")

      -- Check that both keymaps config and on_activate keymaps are set
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")

      local tab_found = false
      local z_found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "<Tab>" then
          tab_found = true
        elseif map.lhs == "z" and map.desc == "Custom on_activate keymap" then
          z_found = true
        end
      end

      assert.is_true(tab_found, "<Tab> from keymaps config should be mapped")
      assert.is_true(z_found, "'z' from on_activate should be mapped")

      -- Test custom on_activate keymap
      feedkeys("z")
      assert.is_true(custom_keymap_set, "Custom on_activate keymap should work")

      -- Clean up
      feedkeys("<Esc>")
    end)
  end)

  describe("operators", function()
    it("applies direct_api operator to all marked occurrences", function()
      bufnr = util.buffer("foo bar baz foo")

      plugin.setup({
        default_operators = false,
        default_keymaps = false,
        operators = {
          d = {
            desc = "Delete",
            method = "direct_api",
            uses_register = true,
            modifies_text = true,
            replacement = function()
              return ""
            end,
          },
        },
      })

      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all foo occurrences)
      feedkeys("q")

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Check that delete operator is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local delete_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Delete" then
          delete_key = map.lhs
          break
        end
      end
      assert.equals("d", delete_key, "Delete key should be mapped")

      -- Apply delete operator to delete marked occurrences
      feedkeys("d$")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals(" bar baz ", lines[1], "Both 'foo' occurrences should be deleted")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")
    end)

    it("applies command operator to all marked occurrences", function()
      bufnr = util.buffer({ "foo bar baz foo", "  foo indented" })

      local normal_key = "q"
      plugin.setup({
        operators = {
          ["<"] = {
            desc = "Indent left",
            method = "command",
            uses_register = false,
            modifies_text = true,
          },
        },
      })
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all foo occurrences)
      feedkeys(normal_key)

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'foo' occurrences should be marked")

      -- Check that left shift operator is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local indent_left_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Indent left" then
          indent_left_key = map.lhs
          break
        end
      end
      assert.equals("<lt>", indent_left_key, "Indent left key should be mapped")

      -- Apply left shift operator to indent marked occurrences
      feedkeys("<j")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar baz foo", "foo indented" }, lines, "Both 'foo' occurrences should be indented left")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")
    end)

    it("applies visual_feedkeys operator to all marked occurrences", function()
      bufnr = util.buffer("foo bar baz foo")

      local normal_key = "q"
      plugin.setup({
        operators = {
          ["gU"] = {
            desc = "Uppercase",
            method = "visual_feedkeys",
            uses_register = false,
            modifies_text = true,
          },
        },
      })
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all foo occurrences)
      feedkeys(normal_key)

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Check that uppercase operator is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local uppercase_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Uppercase" then
          uppercase_key = map.lhs
          break
        end
      end
      assert.equals("gU", uppercase_key, "Uppercase key should be mapped")

      -- Apply uppercase operator to uppercase marked occurrences
      feedkeys("gU$")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("FOO bar baz FOO", lines[1], "Both 'foo' occurrences should be uppercased")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "No marks should remain after applying operator")
    end)

    it("applies visual_feedkeys operator to all marked occurrences in selection", function()
      bufnr = util.buffer("foo bar baz foo")

      local normal_key = "q"
      plugin.setup({
        operators = {
          ["gU"] = {
            desc = "Uppercase",
            method = "visual_feedkeys",
            uses_register = false,
            modifies_text = true,
          },
        },
      })
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all foo occurrences)
      feedkeys(normal_key)

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

      -- Check that uppercase operator is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local uppercase_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Uppercase" then
          uppercase_key = map.lhs
          break
        end
      end
      assert.equals("gU", uppercase_key, "Uppercase key should be mapped")

      feedkeys("v3e") -- Select the first 3 words
      -- Apply uppercase operator to uppercase marked occurrences in selection
      feedkeys("gU")
      vim.wait(0) -- The operator application is async.
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("FOO bar baz foo", lines[1], "First 'foo' should be uppercased")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "One mark should remain for second 'foo'")
    end)

    it("applies visual_feedkeys operator to a count of marked occurrences in selection", function()
      bufnr = util.buffer({ "foo bar baz foo", "bar baz foo bar baz foo" })

      local normal_key = "q"
      plugin.setup({
        operators = {
          ["U"] = {
            desc = "Uppercase",
            method = "visual_feedkeys",
            uses_register = false,
            modifies_text = true,
          },
        },
      })
      vim.keymap.set("n", normal_key, "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all foo occurrences)
      feedkeys(normal_key)

      -- Verify marks are created
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(4, #marks, "All 'foo' occurrences should be marked")

      -- Check that uppercase operator is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local uppercase_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Uppercase" then
          uppercase_key = map.lhs
          break
        end
      end
      assert.equals("U", uppercase_key, "Uppercase key should be mapped")

      feedkeys("Vj") -- Select the first 2 lines
      -- Apply uppercase operator to 2 occurrences
      feedkeys("3U")
      vim.wait(0) -- The operator application is async.
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same(
        { "FOO bar baz FOO", "bar baz FOO bar baz foo" },
        lines,
        "First 3 'foo' occurrences should be uppercased"
      )

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "One mark should remain for fourth 'foo'")
    end)

    it("supports custom operators", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")

      -- Setup plugin with custom operator
      plugin.setup({
        operators = {
          q = {
            desc = "Custom operator: replace with 'test'",
            method = "direct_api",
            uses_register = true,
            modifies_text = true,
            replacement = function()
              return "test"
            end,
          },
        },
      })
      vim.keymap.set("n", "z", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      -- Activate occurrence on 'foo' (marks all foo occurrences)
      feedkeys("z")

      -- Verify marks are created for all 'foo' occurrences
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'foo' occurrences should be marked")

      -- Check that custom operator is mapped
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local custom_key = nil
      for _, map in ipairs(mappings) do
        if map.lhs ~= nil and map.desc == "Custom operator: replace with 'test'" then
          custom_key = map.lhs
          break
        end
      end
      assert.equals("q", custom_key, "Custom operator key should be mapped")

      -- Apply custom operator to replace marked occurrences on first line
      feedkeys("q$")

      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.equals("test bar test", final_lines[1], "First line 'foo' occurrences should be replaced with 'test'")
      assert.equals("baz foo bar", final_lines[2], "Second line should be unchanged")

      -- Should still have one mark remaining on second line
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "One mark should remain on second line")

      -- Clean up remaining marks
      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared after deactivation")
    end)
  end)
end)
