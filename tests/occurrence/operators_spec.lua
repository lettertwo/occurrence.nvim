local assert = require("luassert")
local stub = require("luassert.stub")
local util = require("tests.util")

local Config = require("occurrence.Config")
local Operator = require("occurrence.Operator")
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
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark all occurrences of 'foo'
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Get initial buffer content
      local initial_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "baz foo bar" }, initial_lines)

      -- Apply delete operator
      local operator_config = assert(Config.new():get_operator_config("delete"))
      Operator.apply(occurrence, operator_config, "d", nil, nil, '"')

      -- Check that 'foo' occurrences were deleted
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ " bar ", "baz  bar" }, final_lines)
    end)

    it("saves deleted text to register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark first occurrence only
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply delete operator to default register
      local operator_config = assert(Config.new():get_operator_config("delete"))
      Operator.apply(occurrence, operator_config, "d", nil, nil, '"')

      -- Check register content
      local register_content = vim.fn.getreg('"')
      assert.equals("foo", register_content)
    end)

    it("saves deleted text to specified register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "bar", "word")

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply delete operator to register 'a'
      local operator_config = assert(Config.new():get_operator_config("delete"))
      Operator.apply(occurrence, operator_config, "d", nil, nil, "a")

      -- Check register content
      local register_content = vim.fn.getreg("a")
      assert.equals("bar", register_content)
    end)
  end)

  describe("yank operator", function()
    it("yanks marked occurrences without modifying text", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Get initial buffer content
      local initial_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "baz foo bar" }, initial_lines)

      -- Apply yank operator
      local operator_config = assert(Config.new():get_operator_config("yank"))
      Operator.apply(occurrence, operator_config, "y", nil, nil, '"')

      -- Check that text was not modified
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "baz foo bar" }, final_lines)
    end)

    it("saves yanked text to register", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "bar", "word")

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply yank operator
      local operator_config = assert(Config.new():get_operator_config("yank"))
      Operator.apply(occurrence, operator_config, "y", nil, nil, '"')

      -- Check register content
      local register_content = vim.fn.getreg('"')
      assert.equals("bar", register_content)
    end)

    it("concatenates multiple yanked texts", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Apply yank operator
      local operator_config = assert(Config.new():get_operator_config("yank"))
      Operator.apply(occurrence, operator_config, "y", nil, nil, '"')

      -- Check register content (multiple foo's concatenated)
      local register_content = vim.fn.getreg('"')
      assert.equals("foo\nfoo\nfoo", register_content)
    end)
  end)

  describe("put operator", function()
    it("replaces marked occurrences with register content", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:mark()

      -- Set register 'a' content
      vim.fn.setreg("a", "inserted")

      -- Apply put operator using register 'a'
      local operator_config = assert(Config.new():get_operator_config("put"))
      Operator.apply(occurrence, operator_config, "p", nil, nil, "a")

      -- Check that all 'foo' occurrences were replaced with "inserted"
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "inserted bar inserted", "baz inserted bar" }, final_lines)
    end)

    it("handles empty register gracefully", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Ensure register 'a' is empty
      vim.fn.setreg("a", "")

      -- Should not error
      assert.has_no.errors(function()
        local operator_config = assert(Config.new():get_operator_config("put"))
        Operator.apply(occurrence, operator_config, "p", nil, nil, "a")
      end)

      -- Check that the occurrence was replaced with empty string (deleted)
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ " bar foo", "baz foo bar" }, final_lines)
    end)
  end)

  describe("change operator", function()
    it("replaces marked occurrences with user input", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Mock vim.fn.input to return "test"
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("test")

      -- Apply change operator
      local operator_config = assert(Config.new():get_operator_config("change"))
      Operator.apply(occurrence, operator_config, "c", nil, nil, '"')

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
      local occurrence = Occurrence.get(bufnr, "bar", "word")

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Mock vim.fn.input
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("new")

      -- Apply change operator
      local operator_config = assert(Config.new():get_operator_config("change"))
      Operator.apply(occurrence, operator_config, "c", nil, nil, '"')

      -- Check register content contains original text
      local register_content = vim.fn.getreg('"')
      assert.equals("bar", register_content)

      input_stub:revert()
    end)

    it("uses cached replacement for subsequent edits", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Mock vim.fn.input to return "changed" only once
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("changed")

      -- Apply change operator
      local operator_config = assert(Config.new():get_operator_config("change"))
      Operator.apply(occurrence, operator_config, "c", nil, nil, '"')

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
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      assert.has_no.errors(function()
        local cmd_stub = stub(vim, "cmd")

        local operator_config = assert(Config.new():get_operator_config("indent_left"))
        Operator.apply(occurrence, operator_config, "<", nil, nil, nil)

        -- Verify command was called
        assert.stub(cmd_stub).was_called()

        cmd_stub:revert()
      end)
    end)

    it("indent_format formats indents for lines with occurrences", function()
      bufnr = util.buffer({ "  foo bar foo", "    baz bar", "      baz foo bar" })
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:mark()

      local operator_config = assert(Config.new():get_operator_config("indent_format"))
      Operator.apply(occurrence, operator_config, "=")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "    baz bar", "    baz foo bar" }, lines) -- change expected output as necessary
    end)
  end)

  describe("case operators", function()
    it("uppercases marked occurrences", function()
      bufnr = util.buffer("foo bar foo\nbaz Foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:add_pattern("Foo", "word")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end
      -- Apply change operator with uppercasing
      local operator_config = assert(Config.new():get_operator_config("uppercase"))
      Operator.apply(occurrence, operator_config, "gU", nil, nil, '"')
      -- Check that all 'foo' occurrences were uppercased
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "FOO bar FOO", "baz FOO bar" }, final_lines)
    end)

    it("lowercases marked occurrences", function()
      bufnr = util.buffer("FOO BAR FOO\nBAZ FOO BAR")
      local occurrence = Occurrence.get(bufnr, "FOO", "word")
      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end
      -- Apply change operator with lowercasing
      local operator_config = assert(Config.new():get_operator_config("lowercase"))
      Operator.apply(occurrence, operator_config, "gu", nil, nil, '"')
      -- Check that all 'FOO' occurrences were lowercased
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo BAR foo", "BAZ foo BAR" }, final_lines)
    end)

    it("toggles case of marked occurrences", function()
      bufnr = util.buffer("foo Bar FOO\nbaz Foo BAR")
      local occurrence = Occurrence.get(bufnr, "foo")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Apply change operator with case toggling
      local operator_config = assert(Config.new():get_operator_config("swap_case"))
      Operator.apply(occurrence, operator_config, "g~", nil, nil, '"')

      -- Check that all 'foo' occurrences had their case toggled
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "FOO Bar FOO", "baz Foo BAR" }, final_lines)
    end)
  end)

  describe("get_operator_config", function()
    it("retrieves supported operators", function()
      local config = Config.new()
      assert.is_true(config:operator_is_supported("delete"))
      assert.is_true(config:operator_is_supported("yank"))
      assert.is_true(config:operator_is_supported("change"))
      assert.is_true(config:operator_is_supported("indent_left"))
      assert.is_true(config:operator_is_supported("indent_right"))

      local delete_op = config:get_operator_config("delete")
      local yank_op = config:get_operator_config("yank")
      local change_op = config:get_operator_config("change")
      local indent_left_op = config:get_operator_config("indent_left")
      local indent_right_op = config:get_operator_config("indent_right")

      assert.is_true(Operator.is(delete_op))
      assert.is_true(Operator.is(yank_op))
      assert.is_true(Operator.is(change_op))
      assert.is_true(Operator.is(indent_left_op))
      assert.is_true(Operator.is(indent_right_op))
    end)

    it("supports aliasing operators", function()
      local config = Config.new({
        operators = {
          ["del"] = "delete",
          ["yd"] = "yank",
          ["ch"] = "change",
        },
      })

      assert.is_true(config:operator_is_supported("del"))
      assert.is_true(config:operator_is_supported("yd"))
      assert.is_true(config:operator_is_supported("ch"))

      local del_op = config:get_operator_config("del")
      local yd_op = config:get_operator_config("yd")
      local ch_op = config:get_operator_config("ch")

      assert.is_true(Operator.is(del_op))
      assert.is_true(Operator.is(yd_op))
      assert.is_true(Operator.is(ch_op))

      local delete_op = config:get_operator_config("delete")
      local yank_op = config:get_operator_config("yank")
      local change_op = config:get_operator_config("change")

      assert.is_true(Operator.is(delete_op))
      assert.is_true(Operator.is(yank_op))
      assert.is_true(Operator.is(change_op))
    end)

    it("errors for recursive aliasing", function()
      local config = Config.new({
        operators = {
          ["change"] = "delete",
          ["delete"] = "change",
        },
      })

      assert.error(function()
        config:operator_is_supported("change")
      end, "Circular operator alias detected: 'change' <-> 'delete'")

      assert.error(function()
        config:operator_is_supported("delete")
      end, "Circular operator alias detected: 'delete' <-> 'change'")

      assert.error(function()
        config:get_operator_config("change")
      end, "Circular operator alias detected: 'change' <-> 'delete'")

      assert.error(function()
        config:get_operator_config("delete")
      end, "Circular operator alias detected: 'delete' <-> 'change'")
    end)

    it("returns nil for disabled operators", function()
      local config = Config.new({
        operators = {
          ["disabled_op"] = false,
        },
      })
      assert.is_false(config:operator_is_supported("disabled_op"))
      assert.is_nil(config:get_operator_config("disabled_op"))
    end)

    it("returns nil for unknown operators", function()
      local config = Config.new()
      assert.is_false(config:operator_is_supported("unknown")) -- Unknown operators are supported by default
      assert.is_nil(config:get_operator_config("unknown"))
    end)

    it("uses visual_feedkeys method by default", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Mock vim functions to test the visual_feedkeys path
      local feedkeys_stub = stub(vim.api, "nvim_feedkeys")

      local config = Config.new({
        operators = {
          ["test_op"] = true,
        },
      })

      local fallback_op = assert(config:get_operator_config("test_op"))
      assert.is_true(Operator.is(fallback_op))
      Operator.apply(occurrence, fallback_op, "test_op", nil, nil, nil)

      -- Should feed visual selection and then the operator keys
      assert.stub(feedkeys_stub).was_called_with("v", "nx", true)
      assert.stub(feedkeys_stub).was_called_with("test_op", "nx", true)

      feedkeys_stub:revert()
    end)
  end)

  describe("count parameter", function()
    it("limits operation to specified count", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

      -- Mark all occurrences (there are 3)
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Apply delete with count=1
      local operator_config = assert(Config.new():get_operator_config("delete"))
      Operator.apply(occurrence, operator_config, "d", nil, 1, '"')

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

      local occurrence = Occurrence.get(test_bufnr, "foo", "word")

      -- Mark all occurrences
      for range in occurrence:matches() do
        occurrence:mark(range)
      end

      -- Create a range that covers only the first line
      local Range = require("occurrence.Range")
      local Location = require("occurrence.Location")
      local line1_range = Range.new(Location.new(0, 0), Location.new(0, 7)) -- First line only

      -- Apply delete with range restriction
      local operator_config = assert(Config.new():get_operator_config("delete"))
      Operator.apply(occurrence, operator_config, "d", line1_range, nil, '"')

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
    it("handles empty replacement gracefully", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "foo", "word")

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
        local operator_config = assert(Config.new():get_operator_config("change"))
        Operator.apply(occurrence, operator_config, "c", nil, nil, '"')
      end)

      input_stub:revert()
    end)
  end)

  describe("cursor restoration", function()
    it("restores cursor position after operation", function()
      bufnr = util.buffer("foo bar foo\nbaz foo bar")
      local occurrence = Occurrence.get(bufnr, "bar", "word")

      -- Set initial cursor position
      vim.api.nvim_win_set_cursor(0, { 2, 5 }) -- Line 2, column 5
      local initial_pos = vim.api.nvim_win_get_cursor(0)

      -- Mark first occurrence
      for range in occurrence:matches() do
        occurrence:mark(range)
        break
      end

      -- Apply yank operator (doesn't modify text)
      local operator_config = assert(Config.new():get_operator_config("yank"))
      Operator.apply(occurrence, operator_config, "y", nil, nil, '"')

      -- Cursor should be restored
      local final_pos = vim.api.nvim_win_get_cursor(0)
      assert.same(initial_pos, final_pos)
    end)
  end)
end)
