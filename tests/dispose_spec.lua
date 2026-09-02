local assert = require("luassert")
local stub = require("luassert.stub")
local util = require("tests.util")

local feedkeys = require("occurrence.feedkeys")
local plugin = require("occurrence")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

-- Tests for the `dispose_after_operator` behavior introduced in v2:
-- occurrence mode exits automatically after an operator completes, unless
-- configured otherwise. These tests operate on only *some* marks (via a
-- visual selection that covers only the first occurrence) so that at least
-- one mark always remains. That isolates the `dispose_after_operator`
-- decision from the pre-existing "auto-dispose when no marks remain" path.
describe("dispose_after_operator", function()
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

  -- Marks both 'foo' occurrences, then uppercases only the first via a
  -- visual selection of the first three words. One mark always remains.
  local function mark_and_operate_first()
    bufnr = util.buffer("foo bar baz foo")
    vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

    feedkeys("q") -- mark all 'foo' occurrences and activate occurrence mode
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
    assert.equals(2, #marks, "Both 'foo' occurrences should be marked")

    feedkeys("v3e") -- select first three words ("foo bar baz")
    feedkeys("gU") -- uppercase marked occurrences in selection (only first 'foo')
    vim.wait(0) -- operator application is async
  end

  describe("global option", function()
    it("disposes occurrence mode after an operator by default", function()
      plugin.setup({})
      mark_and_operate_first()

      assert.equals("FOO bar baz foo", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
      assert.is_nil(plugin.get(bufnr), "occurrence should be disposed after the operator")
    end)

    it("preserves occurrence mode when dispose_after_operator = false", function()
      plugin.setup({ dispose_after_operator = false })
      mark_and_operate_first()

      assert.equals("FOO bar baz foo", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1])
      local occ = plugin.get(bufnr)
      assert(occ and not occ:is_disposed(), "occurrence should persist after the operator")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "the un-operated 'foo' should remain marked")
    end)
  end)

  describe("per-operator override", function()
    it("disposes when operator opts in despite global false", function()
      plugin.setup({
        default_operators = false,
        dispose_after_operator = false,
        operators = {
          ["gU"] = {
            desc = "Uppercase",
            operator = "gU",
            dispose_after_operator = true,
          },
        },
      })
      mark_and_operate_first()

      assert.is_nil(plugin.get(bufnr), "per-op override should force disposal")
    end)

    it("preserves when operator opts out despite global true", function()
      plugin.setup({
        default_operators = false,
        dispose_after_operator = true,
        operators = {
          ["gU"] = {
            desc = "Uppercase",
            operator = "gU",
            dispose_after_operator = false,
          },
        },
      })
      mark_and_operate_first()

      local occ = plugin.get(bufnr)
      assert(occ and not occ:is_disposed(), "per-op override should prevent disposal")
    end)
  end)

  describe("toggle_dispose action", function()
    it("prevents disposal for the next operator when global is true", function()
      plugin.setup({})
      bufnr = util.buffer("foo bar baz foo")
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })
      vim.keymap.set("n", "<C-t>", "<Plug>(OccurrenceToggleDispose)", { buffer = bufnr })

      feedkeys("q")
      feedkeys("<C-t>") -- invert dispose for the next operator only
      feedkeys("v3e")
      feedkeys("gU")
      vim.wait(0)

      local occ = plugin.get(bufnr)
      assert(occ and not occ:is_disposed(), "toggle_dispose should prevent disposal once")
    end)

    it("does not invert an operator that sets its own dispose_after_operator", function()
      plugin.setup({
        default_operators = false,
        operators = {
          ["gU"] = {
            desc = "Uppercase",
            operator = "gU",
            dispose_after_operator = false,
          },
        },
      })
      bufnr = util.buffer("foo bar baz foo")
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })
      vim.keymap.set("n", "<C-t>", "<Plug>(OccurrenceToggleDispose)", { buffer = bufnr })

      feedkeys("q")
      feedkeys("<C-t>") -- would force disposal, but the per-op value wins
      feedkeys("v3e")
      feedkeys("gU")
      vim.wait(0)

      local occ = plugin.get(bufnr)
      assert(occ and not occ:is_disposed(), "per-op dispose_after_operator should not be inverted")
      assert.is_nil(occ._invert_next_dispose, "the toggle should still be consumed")
    end)

    it("forces disposal for the next operator when global is false", function()
      plugin.setup({ dispose_after_operator = false })
      bufnr = util.buffer("foo bar baz foo")
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })
      vim.keymap.set("n", "<C-t>", "<Plug>(OccurrenceToggleDispose)", { buffer = bufnr })

      feedkeys("q")
      feedkeys("<C-t>") -- invert dispose for the next operator only
      feedkeys("v3e")
      feedkeys("gU")
      vim.wait(0)

      assert.is_nil(plugin.get(bufnr), "toggle_dispose should force disposal once")
    end)

    it("re-pressing cancels the inversion", function()
      plugin.setup({})
      bufnr = util.buffer("foo bar baz foo")
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })
      vim.keymap.set("n", "<C-t>", "<Plug>(OccurrenceToggleDispose)", { buffer = bufnr })

      feedkeys("q")
      feedkeys("<C-t>") -- invert
      feedkeys("<C-t>") -- cancel inversion -> back to default (dispose)
      feedkeys("v3e")
      feedkeys("gU")
      vim.wait(0)

      assert.is_nil(plugin.get(bufnr), "double toggle should restore default disposal")
    end)

    it("consumes the inversion flag after a single operator", function()
      -- Default global true (dispose). Toggle once so the first operator
      -- persists, and verify the one-shot flag is cleared by that operator.
      plugin.setup({})
      bufnr = util.buffer("foo bar baz foo")
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })
      vim.keymap.set("n", "<C-t>", "<Plug>(OccurrenceToggleDispose)", { buffer = bufnr })

      feedkeys("q") -- mark both 'foo' occurrences
      feedkeys("<C-t>") -- invert dispose for the next operator
      local occ = plugin.get(bufnr)
      assert(occ, "occurrence should be active")
      assert.is_true(occ._invert_next_dispose, "flag should be set by toggle_dispose")

      feedkeys("v3e")
      feedkeys("gU")
      vim.wait(0)

      occ = plugin.get(bufnr)
      assert(occ and not occ:is_disposed(), "inverted operator should not dispose")
      assert.is_nil(occ._invert_next_dispose, "inversion flag should be consumed (one-shot)")
    end)
  end)
end)
