local assert = require("luassert")
local util = require("tests.util")

local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

--- Create a buffer with undo support enabled.
--- Scratch buffers have undolevels=-1 by default, so we need to enable it.
---@param content string | string[]
---@return integer
local function buffer_with_undo(content)
  local buf = util.buffer(content)
  -- Enable undo on the scratch buffer
  vim.bo[buf].undolevels = 1000
  -- Create an undo break so the initial content setup is its own undo entry
  vim.cmd("let &l:undolevels = &l:undolevels")
  return buf
end

--- Trigger TextChanged for the undo module.
--- In the test harness, autocmds don't fire automatically through the event loop.
---@param buf integer
local function trigger_text_changed(buf)
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
end

describe("undo restoration", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      Occurrence.del(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    bufnr = nil
  end)

  it("restores marks after undo of partial delete", function()
    bufnr = buffer_with_undo({
      "foo bar baz",
      "",
      "foo qux foo",
    })

    local occurrence = Occurrence.get(bufnr)
    occurrence:of_word(true, "foo")

    -- Verify 3 marks exist
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(3, #marks, "Should have 3 marks for 'foo'")

    -- Delete foo occurrences only on line 3 (0-indexed line 2)
    occurrence:apply_operator("delete", {
      motion = Range.of_line(2),
      inner = true,
    })

    -- Verify only 1 mark remains (on line 1)
    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(1, #marks, "Should have 1 mark remaining after partial delete")

    -- Undo
    vim.cmd("silent undo")
    trigger_text_changed(bufnr)

    -- Verify text is restored
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "foo bar baz", "", "foo qux foo" }, lines)

    -- Verify all 3 marks are restored
    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(3, #marks, "Should have 3 marks after undo")
  end)

  it("restores occurrence after full consumption", function()
    bufnr = buffer_with_undo("foo bar foo")

    local occurrence = Occurrence.get(bufnr)
    occurrence:of_word(true, "foo")

    -- Verify 2 marks exist
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(2, #marks, "Should have 2 marks for 'foo'")

    -- Delete all foo occurrences (full buffer)
    occurrence:apply_operator("delete", {
      motion = Range.of_buffer(),
      inner = true,
    })

    -- Verify occurrence is disposed (no marks)
    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(0, #marks, "Should have 0 marks after full delete")

    -- Verify occurrence was disposed
    assert.is_false(Occurrence.has(bufnr), "Occurrence should be disposed after full consumption")

    -- Undo
    vim.cmd("silent undo")
    trigger_text_changed(bufnr)

    -- Verify text is restored
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "foo bar foo" }, lines)

    -- Verify occurrence is recreated with marks
    assert.is_true(Occurrence.has(bufnr), "Occurrence should be recreated after undo")
    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(2, #marks, "Should have 2 marks after undo")
  end)

  it("preserves intentional unmarks on undo", function()
    bufnr = buffer_with_undo("foo bar foo baz foo")

    local occurrence = Occurrence.get(bufnr)
    occurrence:of_word(true, "foo")

    -- Verify 3 marks exist
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(3, #marks, "Should have 3 marks for 'foo'")

    -- Unmark the first foo (user intentional unmark)
    local first_match = occurrence:matches()()
    occurrence.extmarks:unmark(first_match)

    -- Verify 2 marks remain
    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(2, #marks, "Should have 2 marks after unmark")

    -- Delete the remaining marked foos
    occurrence:apply_operator("delete", {
      motion = Range.of_buffer(),
      inner = true,
    })

    -- Undo
    vim.cmd("silent undo")
    trigger_text_changed(bufnr)

    -- Verify text is restored
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "foo bar foo baz foo" }, lines)

    -- Should restore only the 2 that the operator removed, not the intentionally unmarked one
    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(2, #marks, "Should have 2 marks after undo (not 3)")
  end)

  it("discards stale records on new edits", function()
    bufnr = buffer_with_undo("foo bar foo")

    local occurrence = Occurrence.get(bufnr)
    occurrence:of_word(true, "foo")

    -- Delete foo occurrences
    occurrence:apply_operator("delete", {
      motion = Range.of_buffer(),
      inner = true,
    })

    -- Create an undo break before making a new edit
    vim.cmd("let &l:undolevels = &l:undolevels")

    -- Make a new edit (not an undo) — this creates a new undo branch
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "new content" })
    trigger_text_changed(bufnr)

    -- Undo should only undo the "new content" edit, not the operator
    vim.cmd("silent undo")
    trigger_text_changed(bufnr)

    -- The buffer should show the state after the delete (inner=true keeps spaces), not the original
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ " bar " }, lines)

    -- No marks should exist (stale record was cleaned up)
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(0, #marks, "Should have no marks after stale undo")
  end)

  it("cleans up on buffer delete", function()
    bufnr = buffer_with_undo("foo bar foo")

    local occurrence = Occurrence.get(bufnr)
    occurrence:of_word(true, "foo")

    -- Delete foo occurrences
    occurrence:apply_operator("delete", {
      motion = Range.of_buffer(),
      inner = true,
    })

    -- Delete buffer should clean up undo state
    local buf_to_delete = bufnr
    bufnr = nil -- prevent after_each from trying to delete again
    vim.api.nvim_buf_delete(buf_to_delete, { force = true })

    -- No error should occur; state should be clean
  end)

end)
