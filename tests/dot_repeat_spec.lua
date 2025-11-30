local assert = require("luassert")
local stub = require("luassert.stub")
local util = require("tests.util")

local feedkeys = require("occurrence.feedkeys")
local plugin = require("occurrence")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

describe("dot repeat functionality", function()
  local bufnr
  local notify_stub

  before_each(function()
    notify_stub = stub(vim, "notify")
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    bufnr = nil
    plugin.reset()
    notify_stub:revert()
  end)

  it("repeats replacement operator on marked occurrences", function()
    bufnr = util.buffer({ "foo bar foo baz", "foo test foo end" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    -- Mark all 'foo' occurrences
    feedkeys("q")

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(4, #marks, "All 'foo' occurrences should be marked")

    -- Delete marked occurrences on first line
    feedkeys("d$")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "foo test foo end" }, lines, "First line 'foo' occurrences should be deleted")

    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(2, #marks, "Two 'foo' marks should remain on second line")

    -- Move to second line and repeat the delete operation
    feedkeys("j")
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "test end" }, lines, "Second line 'foo' occurrences should be deleted by dot-repeat")

    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.same({}, marks, "All marks should be cleared after second operation")
  end)

  it("repeats operator keys on marked occurrences", function()
    bufnr = util.buffer({ "foo bar foo baz", "foo test foo end" })

    plugin.setup({
      default_operators = false,
      operators = {
        ["gU"] = {
          operator = "gU",
        },
        [">"] = {
          operator = ">>",
        },
      },
    })
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    -- Mark all 'foo' occurrences
    feedkeys("q")

    -- Uppercase marked occurrences on first line
    feedkeys("gU$")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "FOO bar FOO baz", "foo test foo end" }, lines, "First line 'foo' should be uppercased")

    -- Move to second line and repeat
    feedkeys("j")
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "FOO bar FOO baz", "FOO test FOO end" }, lines, "Second line 'foo' should be uppercased")

    -- Mark all 'FOO' occurrences
    feedkeys("q")

    -- Indent left
    feedkeys(">$")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "FOO bar FOO baz", "		FOO test FOO end" }, lines, "Second line 'FOO' should be indented left")

    -- Move to top line and repeat
    feedkeys("k")
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "	FOO bar FOO baz", "		FOO test FOO end" }, lines, "First line 'FOO' should be indented left")
  end)

  it("repeats modified operator with count", function()
    bufnr = util.buffer({ "foo bar foo baz foo bar end foo bar" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          mode = "o",
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("o", "o", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

    -- Delete first 2 occurrences of 'foo' to end of line using operator-modifier
    feedkeys("d2o")
    vim.wait(0) -- operator-modifier is async
    feedkeys("$")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz foo bar end foo bar" }, lines, "First 2 'foo' occurrences should be deleted")

    -- Repeat: delete <count> occurrences of word under cursor ('bar')
    feedkeys(".")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "baz foo end foo bar" }, lines, "2 'bar' occurrences should be deleted by dot-repeat")

    -- Repeat: delete <count> occurrences of word under cursor ('baz')
    feedkeys(".")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "foo end foo bar" }, lines, "'baz' occurrence should be deleted by dot-repeat")

    -- Repeat: delete <count> occurrences of word under cursor ('baz')
    feedkeys(".")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "end bar" }, lines, "Last 2 'foo' occurrence should be deleted by dot-repeat")
  end)

  it("repeats operator-modifier with motion, preserving the original word pattern", function()
    -- Tests that `coip` (change occurrence + inner paragraph) remembers the word
    -- it operated on, so dot-repeat applies to the same word in a different location

    bufnr = util.buffer({
      "This is 1st paragraph text.",
      "2nd line also include text text text.",
      "3rd line include text text text",
      "",
      "This is 2nd paragraph text.",
      "2nd line also include text text text.",
      "3rd line include text text text",
      "4th text",
    })

    plugin.setup({
      default_operators = false,
      operators = {
        c = {
          operator = function()
            return "abc"
          end,
        },
      },
    })

    vim.keymap.set("o", "o", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

    feedkeys("4w") -- move to first 'text'
    feedkeys("co")
    vim.wait(0)
    feedkeys("ip")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({
      "This is 1st paragraph abc.",
      "2nd line also include abc abc abc.",
      "3rd line include abc abc abc",
      "",
      "This is 2nd paragraph text.",
      "2nd line also include text text text.",
      "3rd line include text text text",
      "4th text",
    }, lines, "all instances of 'text' in the first paragraph should be replaced with 'abc'")

    feedkeys("}j") -- move to next paragraph
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({
      "This is 1st paragraph abc.",
      "2nd line also include abc abc abc.",
      "3rd line include abc abc abc",
      "",
      "This is 2nd paragraph abc.",
      "2nd line also include abc abc abc.",
      "3rd line include abc abc abc",
      "4th abc",
    }, lines, "all instances of 'text' in the second paragraph should be replaced with 'abc'")
  end)

  it("repeats operator on occurrence mode marks with motion, preserving all marked patterns", function()
    -- Tests that after marking multiple words with `go`, then doing `cip` (change inner paragraph),
    -- dot-repeat preserves all the marked patterns and applies them to a new motion range

    bufnr = util.buffer({
      "This is 1st paragraph text.",
      "2nd line also include text text text.",
      "3rd line include text text text",
      "",
      "This is 2nd paragraph text.",
      "2nd line also include text text text.",
      "3rd line include text text text",
      "4th text",
    })

    plugin.setup({
      default_operators = false,
      operators = {
        c = {
          operator = function()
            return "abc"
          end,
        },
      },
    })

    vim.keymap.set("n", "go", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    feedkeys("4w") -- move to first 'text'
    feedkeys("go") -- add marks for 'text' and activate occurrence mode
    feedkeys("j^w") -- move to first 'line' on second line
    feedkeys("ga") -- add marks for 'line'; `ga` instead of `go` because `go` would toggle only the first mark
    feedkeys("cip")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({
      "This is 1st paragraph abc.",
      "2nd abc also include abc abc abc.",
      "3rd abc include abc abc abc",
      "",
      "This is 2nd paragraph text.",
      "2nd line also include text text text.",
      "3rd line include text text text",
      "4th text",
    }, lines, "all instances of 'text' and 'line' in the first paragraph should be replaced with 'abc'")

    feedkeys("}j") -- move to next paragraph
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({
      "This is 1st paragraph abc.",
      "2nd abc also include abc abc abc.",
      "3rd abc include abc abc abc",
      "",
      "This is 2nd paragraph abc.",
      "2nd abc also include abc abc abc.",
      "3rd abc include abc abc abc",
      "4th abc",
    }, lines, "all instances of 'text' and 'line' in the second paragraph should be replaced with 'abc'")
  end)

  it("repeats modified operator with count and register", function()
    bufnr = util.buffer({ "foo bar foo baz foo bar end foo bar" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("o", "o", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

    -- Delete first 2 occurrences of 'foo' to end of line into register 'a'
    feedkeys('"ad2o')
    vim.wait(0) -- operator-modifier is async
    feedkeys("$")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz foo bar end foo bar" }, lines, "First 2 'foo' occurrences should be deleted")
    assert.same("foo \nfoo ", vim.fn.getreg("a"), "Register should contain 'foo\nfoo'")

    -- Repeat: delete <count> occurrences of word under cursor ('bar') into same register
    feedkeys(".")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "baz foo end foo bar" }, lines, "2 'bar' occurrences should be deleted by dot-repeat")
    assert.same("bar \nbar ", vim.fn.getreg("a"), "Register should contain 'bar\nbar'")

    local reg_b = vim.fn.getreg("b")
    feedkeys('"b.') -- register cannot be changed.
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "foo end foo bar" }, lines, "'baz' occurrence should be deleted by dot-repeat")
    assert.same("baz ", vim.fn.getreg("a"), "Register should still contain 'baz'")
    assert.same(reg_b, vim.fn.getreg("b"), "Register 'b' should be unchanged")
  end)

  it("repeats modified operator with different counts", function()
    bufnr = util.buffer({ "foo bar foo baz foo bar end foo bar" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("o", "o", "<Plug>(OccurrenceModifyOperator)", { buffer = bufnr })

    -- Delete first 2 occurrences of 'foo' to end of line using operator-modifier
    feedkeys("d2o")
    vim.wait(0) -- operator-modifier is async
    feedkeys("$")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz foo bar end foo bar" }, lines, "First 2 'foo' occurrences should be deleted")

    -- Repeat: delete 1 occurrence of word under cursor ('bar')
    feedkeys("1.")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "baz foo bar end foo bar" }, lines, "1 'bar' occurrence should be deleted by dot-repeat")

    -- Repeat: delete 1 occurrence of word under cursor ('baz')
    feedkeys(".")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "foo bar end foo bar" }, lines, "1 'baz' occurrence should be deleted by dot-repeat")

    -- Repeat: delete 1 occurrence of word under cursor ('foo')
    feedkeys(".")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar end foo bar" }, lines, "1 of remaining 'foo' occurrences should be deleted by dot-repeat")
  end)

  it("repeats operator within visual selection", function()
    bufnr = util.buffer({ "foo bar foo baz", "foo test foo end", "foo start foo mid foo end" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    -- Mark all 'foo' occurrences
    feedkeys("q")

    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(7, #marks, "All 'foo' occurrences should be marked")

    -- Delete marked occurrences in first line using visual mode
    feedkeys("V")
    feedkeys("d")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "foo test foo end", "foo start foo mid foo end" }, lines)

    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(5, #marks, "Five 'foo' marks should remain")

    -- Move to second line and repeat in visual mode
    feedkeys("j")
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "test end", "foo start foo mid foo end" }, lines)

    marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(3, #marks, "Three 'foo' marks should remain on third line")
  end)

  it("repeats operator applied programmatically", function()
    bufnr = util.buffer({ "foo bar foo baz", "foo test foo end" })

    plugin.setup({
      default_operators = false,
      operators = {
        delete = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    -- Mark all 'foo' occurrences
    feedkeys("q")

    -- Programmatically invoke the operator on marked occurrences on the current line
    local occ = require("occurrence.Occurrence").get()
    local range = require("occurrence.Range").of_line()
    occ:apply_operator("delete", { motion = range, motion_type = "line" })

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "foo test foo end" }, lines, "'foo' occurrences on the first line should be deleted")

    -- Move to second line, second 'foo' and repeat using dot-repeat
    feedkeys("j3w")
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "test end" }, lines, "All 'foo' occurrences should be deleted")
  end)

  it("repeats operator after deactivation", function()
    bufnr = util.buffer({ "foo bar foo baz", "foo test foo end" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    -- Mark all 'foo' occurrences
    feedkeys("q")

    -- Delete marked occurrences on first line
    feedkeys("d$")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "foo test foo end" }, lines, "'foo' occurrences on the first line should be deleted")

    -- Clear occurrence marks
    feedkeys("<Esc>")
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(0, #marks, "All marks should be cleared")

    -- Move to second line and repeat using dot-repeat
    feedkeys("j")
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "test end" }, lines, "All 'foo' occurrences should be deleted")
  end)

  it("caches cursor position before dot-repeat", function()
    bufnr = util.buffer({ "foo bar foo baz", "test foo test end" })

    plugin.setup({
      default_operators = false,
      operators = {
        d = {
          inner = false,
          operator = function()
            return ""
          end,
        },
      },
    })
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    -- Mark 'foo'
    feedkeys("q")

    -- Delete first line occurrences
    feedkeys("d$")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "test foo test end" }, lines)

    -- Move to second line, move to middle of 'foo'
    feedkeys("jw")
    local cursor_before = vim.api.nvim_win_get_cursor(0)

    -- Dot-repeat should cache cursor position and restore it
    feedkeys(".")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.same({ "bar baz", "test test end" }, lines, "'foo' should be deleted")

    -- Cursor should be restored to cached position
    local cursor_after = vim.api.nvim_win_get_cursor(0)
    assert.same(cursor_before, cursor_after, "Cursor should be restored after dot-repeat")
  end)
end)
