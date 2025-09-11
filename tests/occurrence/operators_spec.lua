local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")
local stub = require("luassert.stub")
local util = require("tests.util")

local Config = require("occurrence.Config")
local operators = require("occurrence.operators")
local Occurrence = require("occurrence.Occurrence")

describe("operators", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    -- Reset registers
    vim.fn.setreg('"', "")
    vim.fn.setreg("a", "")
  end)

  describe("delete operator", function()
    it("deletes marked occurrences", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark all occurrences of 'foo'
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Get initial buffer content
      local initial_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "baz foo bar" }, initial_lines)

      -- Apply delete operator
      operators.get_operator_action("delete")(occurrence, "d", nil, nil, '"')

      -- Check that 'foo' occurrences were deleted
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ " bar ", "baz  bar" }, final_lines)
    end)

    it("saves deleted text to register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark first occurrence only
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply delete operator to default register
      operators.get_operator_action("delete")(occurrence, "d", nil, nil, '"')

      -- Check register content
      local register_content = vim.fn.getreg('"')
      assert.equals("foo", register_content)
    end)

    it("saves deleted text to specified register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "bar", {})

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply delete operator to register 'a'
      operators.get_operator_action("delete")(occurrence, "d", nil, nil, "a")

      -- Check register content
      local register_content = vim.fn.getreg("a")
      assert.equals("bar", register_content)
    end)
  end)

  describe("yank operator", function()
    it("yanks marked occurrences without modifying text", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Get initial buffer content
      local initial_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "baz foo bar" }, initial_lines)

      -- Apply yank operator
      operators.get_operator_action("yank")(occurrence, "y", nil, nil, '"')

      -- Check that text was not modified
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "baz foo bar" }, final_lines)
    end)

    it("saves yanked text to register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "bar", {})

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply yank operator
      operators.get_operator_action("yank")(occurrence, "y", nil, nil, '"')

      -- Check register content
      local register_content = vim.fn.getreg('"')
      assert.equals("bar", register_content)
    end)

    it("concatenates multiple yanked texts", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Apply yank operator
      operators.get_operator_action("yank")(occurrence, "y", nil, nil, '"')

      -- Check register content (multiple foo's concatenated)
      local register_content = vim.fn.getreg('"')
      assert.equals("foo\nfoo\nfoo", register_content)
    end)
  end)

  describe("change operator", function()
    it("replaces marked occurrences with user input", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Mock vim.fn.input to return "test"
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("test")

      -- Apply change operator
      operators.get_operator_action("change")(occurrence, "c", nil, nil, '"')

      -- Check that all 'foo' occurrences were replaced with "test"
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "test bar test", "baz test bar" }, final_lines)

      -- Verify input was called
      assert.stub(input_stub).was_called_with({
        prompt = "Change to: ",
        default = "foo",
        cancelreturn = false,
      })

      input_stub:revert()
    end)

    it("saves original text to register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "bar", {})

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Mock vim.fn.input
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("new")

      -- Apply change operator
      operators.get_operator_action("change")(occurrence, "c", nil, nil, '"')

      -- Check register content contains original text
      local register_content = vim.fn.getreg('"')
      assert.equals("bar", register_content)

      input_stub:revert()
    end)

    it("uses cached replacement for subsequent edits", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Mock vim.fn.input to return "changed" only once
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("changed")

      -- Apply change operator
      operators.get_operator_action("change")(occurrence, "c", nil, nil, '"')

      -- Check that all occurrences were changed to the same text
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "changed bar changed", "baz changed bar" }, final_lines)

      -- Verify input was called only once (for the first edit)
      assert.stub(input_stub).was_called(1)

      input_stub:revert()
    end)
  end)

  describe("indent operators", function()
    it("indent_left and indent_right are command-based operators", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      -- Test that these don't error when called
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      assert.has_no.errors(function()
        local cmd_stub = stub(vim, "cmd")

        operators.get_operator_action("indent_left")(occurrence, "<", nil, nil, nil)

        -- Verify command was called
        assert.stub(cmd_stub).was_called()

        cmd_stub:revert()
      end)
    end)
  end)

  describe("get_operator_action", function()
    it("retrieves supported operators", function()
      assert.is_true(operators.is_supported("delete"))
      assert.is_true(operators.is_supported("yank"))
      assert.is_true(operators.is_supported("change"))
      assert.is_true(operators.is_supported("indent_left"))
      assert.is_true(operators.is_supported("indent_right"))

      local delete_op = operators.get_operator_action("delete")
      local yank_op = operators.get_operator_action("yank")
      local change_op = operators.get_operator_action("change")
      local indent_left_op = operators.get_operator_action("indent_left")
      local indent_right_op = operators.get_operator_action("indent_right")

      assert.is_true(delete_op:is_action())
      assert.is_true(yank_op:is_action())
      assert.is_true(change_op:is_action())
      assert.is_true(indent_left_op:is_action())
      assert.is_true(indent_right_op:is_action())
    end)

    it("supports aliasing operators", function()
      local config = Config.new({
        keymap = {
          operators = {
            ["del"] = "delete",
            ["yd"] = "yank",
            ["ch"] = "change",
          },
        },
      })

      assert.is_true(operators.is_supported("del", config))
      assert.is_true(operators.is_supported("yd", config))
      assert.is_true(operators.is_supported("ch", config))

      local del_op = operators.get_operator_action("del", config)
      local yd_op = operators.get_operator_action("yd", config)
      local ch_op = operators.get_operator_action("ch", config)

      assert.is_true(del_op:is_action())
      assert.is_true(yd_op:is_action())
      assert.is_true(ch_op:is_action())

      local delete_op = operators.get_operator_action("delete")
      local yank_op = operators.get_operator_action("yank")
      local change_op = operators.get_operator_action("change")

      assert.equals(delete_op, del_op)
      assert.equals(yank_op, yd_op)
      assert.equals(change_op, ch_op)
    end)

    it("errors for recursive aliasing", function()
      local config = Config.new({
        keymap = {
          operators = {
            ["change"] = "delete",
            ["delete"] = "change",
          },
        },
      })

      assert.error(function()
        operators.is_supported("change", config)
      end, "Circular operator alias detected: 'change' <-> 'delete'")

      assert.error(function()
        operators.is_supported("delete", config)
      end, "Circular operator alias detected: 'delete' <-> 'change'")

      assert.error(function()
        operators.get_operator_action("change", config)
      end, "Circular operator alias detected: 'change' <-> 'delete'")

      assert.error(function()
        operators.get_operator_action("delete", config)
      end, "Circular operator alias detected: 'delete' <-> 'change'")
    end)

    it("creates default configs for enabled operators", function()
      local config = Config.new({
        keymap = {
          operators = {
            ["custom1"] = true,
          },
        },
      })
      assert.is_true(operators.is_supported("custom1", config))

      local custom1_op = operators.get_operator_action("custom1", config)

      assert.is_true(custom1_op:is_action())
    end)

    it("errors for disabled operators", function()
      local config = Config.new({
        keymap = {
          operators = {
            ["nonexistent_op"] = false,
          },
        },
      })
      assert.is_false(operators.is_supported("nonexistent_op", config))
      assert.error(function()
        operators.get_operator_action("nonexistent_op", config)
      end)
    end)

    it("creates a fallback operator for unknown operators", function()
      local unknown_op = operators.get_operator_action("unknown")
      assert.is_true(operators.is_supported("unknown")) -- Unknown operators are supported by default
      assert.is_true(unknown_op:is_action())
    end)

    it("returns cached operator on subsequent calls", function()
      local op1 = operators.get_operator_action("custom1")
      local op2 = operators.get_operator_action("custom1")

      assert.equals(op1, op2) -- Should be the same instance
    end)

    it("creates different operators for different names", function()
      local op1 = operators.get_operator_action("custom2")
      local op2 = operators.get_operator_action("custom3")

      assert.is_not.equals(op1, op2) -- Should be different instances
    end)

    it("fallback operators use visual_feedkeys method", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Mock vim functions to test the visual_feedkeys path
      local cmd_stub = stub(vim, "cmd")
      local feedkeys_stub = stub(vim.api, "nvim_feedkeys")

      local fallback_op = operators.get_operator_action("test_op")
      fallback_op(occurrence, "test_op", nil, nil, nil)

      -- Should call normal! v and feedkeys
      assert.stub(cmd_stub).was_called_with("normal! v")
      assert.stub(feedkeys_stub).was_called_with("test_op", "x", true)

      cmd_stub:revert()
      feedkeys_stub:revert()
    end)
  end)

  describe("count parameter", function()
    it("limits operation to specified count", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark all occurrences (there are 3)
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Apply delete with count=1
      operators.get_operator_action("delete")(occurrence, "d", nil, 1, '"')

      -- Only one 'foo' should be deleted
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local remaining_content = table.concat(final_lines, " ")
      local remaining_foo_count = select(2, string.gsub(remaining_content, "foo", ""))
      assert.equals(2, remaining_foo_count) -- Should have 2 'foo's remaining
    end)
  end)

  describe("range parameter", function()
    it("applies operation only to occurrences in range", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      -- Create multi-line buffer
      local test_bufnr = util.buffer("foo bar\nfoo baz\nfoo qux")
      vim.api.nvim_set_current_buf(test_bufnr)

      local occurrence = Occurrence.new(test_bufnr, "foo", {})

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Create a range that covers only the first line
      local Range = require("occurrence.Range")
      local Location = require("occurrence.Location")
      local line1_range = Range.new(Location.new(0, 0), Location.new(0, 7)) -- First line only

      -- Apply delete with range restriction
      operators.get_operator_action("delete")(occurrence, "d", line1_range, nil, '"')

      -- Only 'foo' in first line should be affected
      local final_lines = vim.api.nvim_buf_get_lines(test_bufnr, 0, -1, false)
      local remaining_content = table.concat(final_lines, " ")
      local remaining_foo_count = select(2, string.gsub(remaining_content, "foo", ""))
      assert.is_true(remaining_foo_count < 3) -- Some were deleted
      assert.is_true(remaining_foo_count > 0) -- Some remain

      vim.api.nvim_buf_delete(test_bufnr, { force = true })
    end)
  end)

  describe("error handling", function()
    it("logs error when no occurrences are marked", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      local occurrence = Occurrence.new(bufnr, "foo", {})
      -- Don't mark any occurrences

      operators.get_operator_action("delete")(occurrence, "d", nil, nil, '"')

      assert.spy(vim.notify).was_called_with(match.has_match("No occurrences"), vim.log.levels.ERROR, match._)

      -- restore original notify
      vim.notify = original_notify
    end)

    it("handles empty replacement gracefully", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "foo", {})

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Mock vim.fn.input to return empty string
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("")

      -- Should not error
      assert.has_no.errors(function()
        operators.get_operator_action("change")(occurrence, "c", nil, nil, '"')
      end)

      input_stub:revert()
    end)
  end)

  describe("cursor restoration", function()
    it("restores cursor position after operation", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.new(bufnr, "bar", {})

      -- Set initial cursor position
      vim.api.nvim_win_set_cursor(0, { 2, 5 }) -- Line 2, column 5
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply yank operator (doesn't modify text)
      operators.get_operator_action("yank")(occurrence, "y", nil, nil, '"')

      -- Cursor should be restored
      local final_pos = vim.api.nvim_win_get_cursor(0)
      assert.same(initial_pos, final_pos)
    end)
  end)
end)
