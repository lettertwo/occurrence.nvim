local assert = require("luassert")
local feedkeys = require("occurrence.feedkeys")
local plugin = require("occurrence")
local stub = require("luassert.stub")
local util = require("tests.util")

describe(":Occurrence command", function()
  local bufnr
  local MARK_NS

  before_each(function()
    plugin.setup({})
    MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    plugin.reset()
  end)

  describe("basic subcommands", function()
    it("executes :Occurrence mark", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo end" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      vim.cmd("Occurrence mark")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "Should mark all 'foo' occurrences")
    end)

    it("executes :Occurrence deactivate", function()
      bufnr = util.buffer({ "foo bar foo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks)

      vim.cmd("Occurrence deactivate")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "Should clear all marks")
    end)

    it("executes :Occurrence toggle", function()
      bufnr = util.buffer({ "foo bar foo baz" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- On first 'foo'

      -- Toggle on
      vim.cmd("Occurrence toggle")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "Should mark first 'foo'")

      -- Toggle off
      vim.cmd("Occurrence toggle")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "Should unmark first 'foo'")
    end)
  end)

  describe("with count", function()
    it("deletes first N marked occurrences with count", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo end", "foo test foo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Mark all 'foo' occurrences (5 total)
      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks)

      -- Delete first 2 occurrences
      vim.cmd("2Occurrence delete")

      -- Motion to end of buffer
      feedkeys("G")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "bar", "baz foo end", "foo test foo" }, lines)
    end)

    it("yanks first N marked occurrences with count", function()
      bufnr = util.buffer({ "foo bar foo baz foo", "foo bar bat foo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks)

      -- Yank first 2 occurrences
      vim.cmd("2Occurrence yank")

      feedkeys("G")

      local reg_contents = vim.fn.getreg('"')
      assert.equals("foo\nfoo", reg_contents)
    end)

    it("moves to Nth marked occurrence with count", function()
      bufnr = util.buffer({ "foo bar foo", "baz foo end", "foo test foo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks)

      -- Move to 3rd occurrence
      vim.cmd("3Occurrence next")

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.same({ 3, 0 }, cursor)

      -- Move 3 occurrences forward
      vim.cmd("Occurrence next 3")
      assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))

      -- Move 3 occurrences backward, preferring right-most count
      vim.cmd("2Occurrence previous 3")
      assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
    end)
  end)

  describe("with range", function()
    it("deletes marked occurrences in range", function()
      bufnr = util.buffer({
        "foo bar foo", -- line 1
        "baz foo end", -- line 2
        "foo test foo", -- line 3
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Mark all 'foo' occurrences (5 total)
      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks)

      -- Delete occurrences in lines 2-3
      vim.cmd("2,3Occurrence delete")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "foo bar foo", -- line 1: untouched
        "baz end", -- line 2: 'foo' deleted
        "test", -- line 3: both 'foo' deleted
      }, lines)

      -- Should still have 2 marks on line 1
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks)
    end)

    it("changes marked occurrences in range", function()
      bufnr = util.buffer({
        "foo bar foo",
        "baz foo end",
        "foo test foo",
      })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Mark all occurrences
      vim.cmd("Occurrence mark")

      -- Mock vim.fn.input to return "bar"
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("bar")

      -- Change occurrences in line 2 only
      vim.cmd("2,2Occurrence change")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "foo bar foo", -- line 1: untouched
        "baz bar end", -- line 2: 'foo' -> 'bar'
        "foo test foo", -- line 3: untouched
      }, lines)

      input_stub:revert()
    end)
  end)

  describe("with register", function()
    it("yanks marked occurrences to specified register", function()
      bufnr = util.buffer({ "foo bar foo baz foo", "foo bar bat foo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks)

      -- Yank to register 'a'
      vim.cmd("Occurrence yank a")
      feedkeys("G")

      local reg_contents = vim.fn.getreg("a")
      assert.equals("foo\nfoo\nfoo\nfoo\nfoo", reg_contents)
    end)

    it("puts at marked occurrences from specified register", function()
      bufnr = util.buffer({ "foo bar foo baz foo", "foo bar bat foo" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      vim.cmd("Occurrence mark")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks)

      -- Set register 'b' to some text
      vim.fn.setreg("b", "INSERTED")

      -- Put from register 'b' at first 2 marked occurrences
      vim.cmd("2Occurrence put b")
      feedkeys("G")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "INSERTED bar INSERTED baz foo",
        "foo bar bat foo",
      }, lines)
    end)
  end)

  describe("modify_operator subcommand", function()
    it("errors if not in operator-pending mode", function()
      bufnr = util.buffer({ "foo bar foo baz" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      assert.error(function()
        vim.cmd("Occurrence modify_operator")
      end)
    end)

    it("accepts an operator argument", function()
      bufnr = util.buffer({ "foo bar foo baz", "test foo end" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      -- Execute modify_operator with 'd' operator
      vim.cmd("Occurrence modify_operator d")
      vim.wait(0)
      feedkeys("G")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({ "bar baz", "test end" }, lines)
    end)
  end)
end)
