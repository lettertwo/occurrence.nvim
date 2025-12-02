local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")
local stub = require("luassert.stub")
local util = require("tests.util")

local builtins = require("occurrence.api")
local feedkeys = require("occurrence.feedkeys")
local plugin = require("occurrence")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

describe("User event tests", function()
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

  describe("OccurrenceCreate", function()
    it("should execute when an occurrence instance is first created", function()
      bufnr = util.buffer("foo bar baz foo")
      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      local callback = spy.new()

      local listener_id = vim.api.nvim_create_autocmd("User", {
        pattern = "OccurrenceCreate",
        callback = function(...)
          callback(...)
        end,
      })

      feedkeys("q")
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_called(1)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceCreate",
        file = "OccurrenceCreate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("q")
      assert.spy(callback).was_called(1)

      feedkeys("<Esc>")
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")

      -- Create occurrence directly
      require("occurrence.Occurrence").get(bufnr)
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_called(2)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceCreate",
        file = "OccurrenceCreate",
        buf = bufnr,
        id = listener_id,
      }))

      -- Dispose occurrence
      require("occurrence.Occurrence").del(bufnr)
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")
      assert.spy(callback).was_called(2)
    end)
  end)

  describe("OccurrenceActivate", function()
    it("should execute when an occurrence instance is activated", function()
      bufnr = util.buffer("foo bar baz foo")
      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      local callback = spy.new()

      local listener_id = vim.api.nvim_create_autocmd("User", {
        pattern = "OccurrenceActivate",
        callback = function(...)
          callback(...)
        end,
      })

      -- Create occurrence before activating
      require("occurrence.Occurrence").get(bufnr)
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_not_called()

      feedkeys("q")
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_called(1)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceActivate",
        file = "OccurrenceActivate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("q")
      assert.spy(callback).was_called(1)

      feedkeys("<Esc>")
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")

      feedkeys("q")
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_called(2)

      feedkeys("<Esc>")
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")
      assert.spy(callback).was_called(2)
    end)
  end)

  describe("OccurrenceUpdate", function()
    it("should execute when an occurrence pattern is added", function()
      bufnr = util.buffer("foo bar baz foo")
      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      local callback = spy.new()

      local listener_id = vim.api.nvim_create_autocmd("User", {
        pattern = "OccurrenceUpdate",
        callback = function(...)
          callback(...)
        end,
      })

      feedkeys("q")
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_called(1)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceUpdate",
        file = "OccurrenceUpdate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("q")
      assert.spy(callback).was_called(1)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceUpdate",
        file = "OccurrenceUpdate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("<Esc>")
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")
      assert.spy(callback).was_called(1)
    end)

    it("should execute when a mark is toggled", function()
      bufnr = util.buffer("foo bar baz foo")
      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })
      vim.keymap.set("n", "n", "<Plug>(OccurrenceNext)", { buffer = bufnr })
      vim.keymap.set("n", "t", "<Plug>(OccurrenceToggle)", { buffer = bufnr })
      vim.keymap.set("n", "Q", "<Plug>(OccurrenceUnmark)", { buffer = bufnr })

      local callback = spy.new()

      local listener_id = vim.api.nvim_create_autocmd("User", {
        pattern = "OccurrenceUpdate",
        callback = function(...)
          callback(...)
        end,
      })

      feedkeys("q")
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")
      assert.spy(callback).was_called(1)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceUpdate",
        file = "OccurrenceUpdate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("n") -- move to next occurrence
      assert.spy(callback).was_called(1)

      feedkeys("Q") -- unmark
      assert.spy(callback).was_called(2)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceUpdate",
        file = "OccurrenceUpdate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("t") -- toggle (should mark again)
      assert.spy(callback).was_called(3)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceUpdate",
        file = "OccurrenceUpdate",
        buf = bufnr,
        id = listener_id,
      }))

      feedkeys("q") -- should not add a new mark (already marked)
      assert.spy(callback).was_called(3)

      feedkeys("<Esc>")
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")
      assert.spy(callback).was_called(3)
    end)
  end)

  describe("OccurrenceDispose", function()
    it("should execute when an occurrence instance is disposed", function()
      bufnr = util.buffer("foo bar baz foo")
      plugin.setup({})
      vim.keymap.set("n", "q", "<Plug>(OccurrenceMark)", { buffer = bufnr })

      local callback = spy.new()

      local listener_id = vim.api.nvim_create_autocmd("User", {
        pattern = "OccurrenceDispose",
        callback = function(...)
          callback(...)
        end,
      })

      feedkeys("q")
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")

      feedkeys("<Esc>")
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")
      assert.spy(callback).was_called(1)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceDispose",
        file = "OccurrenceDispose",
        buf = bufnr,
        id = listener_id,
      }))

      -- Create occurrence directly
      require("occurrence.Occurrence").get(bufnr)
      assert.is_not_nil(require("occurrence").get(bufnr), "Occurrence instance should be created")

      -- Dispose occurrence
      require("occurrence.Occurrence").del(bufnr)
      assert.is_nil(require("occurrence").get(bufnr), "Occurrence instance should be removed after escaping")
      assert.spy(callback).was_called(2)
      assert.spy(callback).was_called_with(match.same({
        event = "User",
        match = "OccurrenceDispose",
        file = "OccurrenceDispose",
        buf = bufnr,
        id = listener_id,
      }))
    end)
  end)
end)
