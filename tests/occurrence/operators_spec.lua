local assert = require("luassert")
local stub = require("luassert.stub")
local util = require("tests.util")

local Config = require("occurrence.Config")
local Location = require("occurrence.Location")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")

describe("operators", function()
  local bufnr

  before_each(function()
    vim.o.expandtab = true
    vim.o.tabstop = 2
    vim.o.shiftwidth = 2
  end)

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
      occurrence:apply_operator("delete", { motion = Range.of_buffer() })

      -- Check that 'foo' occurrences were deleted
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "bar", "baz bar" }, final_lines)
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
      occurrence:apply_operator("delete", { motion = Range.of_buffer() })

      -- Check register content
      local register_content = vim.fn.getreg('"')
      assert.equals("foo ", register_content)
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
      occurrence:apply_operator("delete", { motion = Range.of_buffer(), register = "a" })

      -- Check register content
      local register_content = vim.fn.getreg("a")
      assert.equals("bar ", register_content)
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
      occurrence:apply_operator("yank", { motion = Range.of_buffer() })

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
      occurrence:apply_operator("yank", { motion = Range.of_buffer(), register = '"' })

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
      occurrence:apply_operator("yank", { motion = Range.of_buffer(), register = '"' })

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
      occurrence:apply_operator("put", { motion = Range.of_buffer(), register = "a" })

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
        occurrence:apply_operator("put", { motion = Range.of_buffer(), register = "a" })
      end)

      -- Check that the occurrence was replaced with empty string (deleted)
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ " bar foo", "baz foo bar" }, final_lines)
    end)

    it("handles multi-line register content", function()
      bufnr = util.buffer("source1 source2 source3\ndest dest dest")

      -- Step 1: Yank multiple occurrences of "source"
      local source_occurrence = Occurrence.get(bufnr, "source\\d", "pattern")
      for range in source_occurrence:matches() do
        source_occurrence:mark(range)
      end

      source_occurrence:apply_operator("yank", { motion = Range.of_buffer(), register = '"' })

      -- Verify register has newline-separated content
      local register_content = vim.fn.getreg('"')
      assert.equals("source1\nsource2\nsource3", register_content)

      -- Step 2: Put the multi-line register content at destination occurrences
      local dest_occurrence = Occurrence.get(bufnr, "dest", "word")
      for range in dest_occurrence:matches() do
        dest_occurrence:mark(range)
      end

      -- Apply put operator - should replicate multi-line content at each occurrence
      assert.has_no.errors(function()
        dest_occurrence:apply_operator("put", { motion = Range.of_buffer(), register = '"' })
      end)

      -- Check that multi-line content was inserted at each destination
      -- Each "dest" gets replaced with all 3 lines
      -- Since marks are processed in reverse: last dest, middle dest, first dest
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "source1 source2 source3",
        "source1",
        "source2",
        "source3 source1",
        "source2",
        "source3 source1",
        "source2",
        "source3",
      }, final_lines)
    end)
  end)

  describe("distribute operator", function()
    it("distributes lines from register across marked occurrences", function()
      bufnr = util.buffer("source1 source2 source3\ndest dest dest")

      -- Step 1: Yank multiple occurrences of "source"
      local source_occurrence = Occurrence.get(bufnr, "source\\d", "pattern")
      for range in source_occurrence:matches() do
        source_occurrence:mark(range)
      end

      source_occurrence:apply_operator("yank", { motion = Range.of_buffer(), register = '"' })

      -- Verify register has newline-separated content
      local register_content = vim.fn.getreg('"')
      assert.equals("source1\nsource2\nsource3", register_content)

      -- Step 2: Distribute the lines across destination occurrences
      local dest_occurrence = Occurrence.get(bufnr, "dest", "word")
      for range in dest_occurrence:matches() do
        dest_occurrence:mark(range)
      end

      -- Apply distribute operator
      assert.has_no.errors(function()
        dest_occurrence:apply_operator("distribute", { motion = Range.of_buffer(), register = '"' })
      end)

      -- Check that each destination got one line (distributed)
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "source1 source2 source3",
        "source1 source2 source3",
      }, final_lines)
    end)

    it("cycles through lines when more destinations than lines", function()
      bufnr = util.buffer({ "alpha beta", "PLACE PLACE PLACE PLACE PLACE" })

      -- Yank "alpha" and "beta" (2 values) using word pattern
      local source_occurrence = Occurrence.get(bufnr, "\\(alpha\\|beta\\)", "pattern")
      -- Mark only the first 2 matches
      local count = 0
      for range in source_occurrence:matches() do
        if count < 2 then
          source_occurrence:mark(range)
          count = count + 1
        end
      end

      source_occurrence:apply_operator("yank", { motion = Range.of_buffer(), register = '"' })

      -- Verify register has 2 lines
      local register_content = vim.fn.getreg('"')
      assert.equals("alpha\nbeta", register_content)

      -- Distribute across 5 destinations (should cycle: alpha, beta, alpha, beta, alpha)
      local dest_occurrence = Occurrence.get(bufnr, "PLACE", "word")
      for range in dest_occurrence:matches() do
        dest_occurrence:mark(range)
      end

      dest_occurrence:apply_operator("distribute", { motion = Range.of_buffer(), register = '"' })

      -- Check that distribution cycled correctly
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "alpha beta",
        "alpha beta alpha beta alpha",
      }, final_lines)
    end)

    it("uses first N lines when more lines than destinations", function()
      bufnr = util.buffer("foo bar baz qux quux\nPLACE PLACE")

      -- Yank 5 values from first line
      local source_occurrence = Occurrence.get(bufnr, "\\w\\+", "pattern")
      -- Only mark the first 5 matches (which are all on line 1)
      local count = 0
      for range in source_occurrence:matches() do
        if count < 5 then
          source_occurrence:mark(range)
          count = count + 1
        end
      end

      source_occurrence:apply_operator("yank", { motion = Range.of_buffer(), register = '"' })

      -- Verify register has 5 lines
      local register_content = vim.fn.getreg('"')
      assert.equals("foo\nbar\nbaz\nqux\nquux", register_content)

      -- Distribute to only 2 destinations (should use only first 2: foo, bar)
      local dest_occurrence = Occurrence.get(bufnr, "PLACE", "word")
      for range in dest_occurrence:matches() do
        dest_occurrence:mark(range)
      end

      dest_occurrence:apply_operator("distribute", { motion = Range.of_buffer(), register = '"' })

      -- Check that only first 2 lines were used
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "foo bar baz qux quux",
        "foo bar",
      }, final_lines)
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
      occurrence:apply_operator("change", { motion = Range.of_buffer() })

      -- Check that all 'foo' occurrences were replaced with "test"
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "test bar test", "baz test bar" }, final_lines)

      -- Verify input was called
      assert.stub(input_stub).was_called_with({
        prompt = "Change to: ",
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
      occurrence:apply_operator("change", { motion = Range.of_buffer(), register = '"' })

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
      occurrence:apply_operator("change", { motion = Range.of_buffer(), register = '"' })

      -- Check that all occurrences were changed to the same text
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "changed bar changed", "baz changed bar" }, final_lines)

      -- Verify input was called only once (for the first edit)
      assert.stub(input_stub).was_called(1)

      input_stub:revert()
    end)
  end)

  describe("indent operators", function()
    it("indent_right indents lines with occurrences", function()
      bufnr = util.buffer({ "foo bar foo", "  baz bar", "    baz foo bar" })
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:mark()

      occurrence:apply_operator("indent_right", { motion = Range.of_buffer() })

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "    foo bar foo", "  baz bar", "      baz foo bar" }, lines)
    end)

    it("indent_left unindents lines with occurrences", function()
      bufnr = util.buffer({ "  foo bar foo", "    baz bar", "      baz foo bar" })
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:mark()

      occurrence:apply_operator("indent_left", { motion = Range.of_buffer() })

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "foo bar foo", "    baz bar", "    baz foo bar" }, lines)
    end)

    it("indent_format formats indents for lines with occurrences", function()
      bufnr = util.buffer({ "  foo bar foo", "    baz bar", "      baz foo bar" })
      local occurrence = Occurrence.get(bufnr, "foo", "word")
      occurrence:mark()

      occurrence:apply_operator("indent_format", { motion = Range.of_buffer() })

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
      occurrence:apply_operator("uppercase", { motion = Range.of_buffer() })
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
      occurrence:apply_operator("lowercase", { motion = Range.of_buffer() })
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
      occurrence:apply_operator("swap_case", { motion = Range.of_buffer() })

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

      local delete_op = assert(config:get_operator_config("delete"))
      local yank_op = assert(config:get_operator_config("yank"))
      local change_op = assert(config:get_operator_config("change"))
      local indent_left_op = assert(config:get_operator_config("indent_left"))
      local indent_right_op = assert(config:get_operator_config("indent_right"))

      assert.is_truthy(delete_op.operator)
      assert.is_truthy(yank_op.operator)
      assert.is_truthy(change_op.operator)
      assert.is_truthy(indent_left_op.operator)
      assert.is_truthy(indent_right_op.operator)
    end)

    it("returns nil for unknown operators", function()
      local config = Config.new()
      assert.is_false(config:operator_is_supported("unknown")) -- Unknown operators are supported by default
      assert.is_nil(config:get_operator_config("unknown"))
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
      occurrence:apply_operator("delete", { motion = Range.of_buffer(), count = 1 })

      -- Only one 'foo' should be deleted
      local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local remaining_content = table.concat(final_lines, " ")
      local remaining_foo_count = select(2, string.gsub(remaining_content, "foo", ""))
      assert.equals(2, remaining_foo_count) -- Should have 2 'foo's remaining
    end)
  end)

  describe("motion parameter", function()
    it("applies operation only to occurrences in motion range", function()
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
      local line1_range = Range.new(Location.new(0, 0), Location.new(0, 7)) -- First line only

      -- Apply delete with range restriction
      occurrence:apply_operator("delete", { motion = line1_range })

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
        occurrence:apply_operator("change", { motion = Range.of_buffer() })
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
      occurrence:apply_operator("yank", { motion = "G" })

      -- Cursor should be restored
      local final_pos = vim.api.nvim_win_get_cursor(0)
      assert.same(initial_pos, final_pos)
    end)
  end)
end)
