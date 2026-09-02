local assert = require("luassert")
local match = require("luassert.match")
local stub = require("luassert.stub")
local util = require("tests.util")

local Location = require("occurrence.Location")
local mcursor = require("occurrence.mcursor")

describe("mcursor (stable, unsupported nvim)", function()
  local bufnr
  local notify_stub
  local real_nvim_mcursor
  local real_config_module

  before_each(function()
    real_nvim_mcursor = rawget(vim.api, "nvim_mcursor")
    real_config_module = package.loaded["occurrence.Config"]
    vim.api.nvim_mcursor = nil ---@diagnostic disable-line: inject-field
    notify_stub = stub(vim, "notify")
  end)

  after_each(function()
    notify_stub:revert()
    vim.api.nvim_mcursor = real_nvim_mcursor ---@diagnostic disable-line: inject-field
    -- Restore the cached module (by assignment, never by re-`require`-ing
    -- under the stub) only after `nvim_mcursor` is back, so a later test
    -- that does re-require `occurrence.Config` sees the real API.
    package.loaded["occurrence.Config"] = real_config_module
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    bufnr = nil
  end)

  it("is_supported reports false", function()
    assert.is_false(mcursor.is_supported())
  end)

  it("add notifies and does not create cursors", function()
    bufnr = util.buffer("foo bar foo baz foo")
    mcursor.add({ Location.new(0, 0) })

    assert
      .spy(notify_stub)
      .was_called_with(match.is_match("nvim_mcursor"), vim.log.levels.ERROR, { title = "Occurrence" })
  end)

  it("Q/I/A default keys are not registered when the running nvim lacks nvim_mcursor", function()
    -- The gating happens once at module load, so exercise it by forcing
    -- a fresh load of occurrence.Config with nvim_mcursor stubbed out.
    -- `after_each` restores the real cached module (by assignment) once
    -- `nvim_mcursor` itself is restored, so we never re-require it here.
    package.loaded["occurrence.Config"] = nil
    local ok, Config = pcall(require, "occurrence.Config")

    assert.is_true(ok)
    local default_config = Config.default()
    assert.is_nil(default_config.keymaps["Q"])
    assert.is_nil(default_config.operators["I"])
    assert.is_nil(default_config.operators["A"])
  end)

  it("cursors action notifies and disposes when unsupported", function()
    bufnr = util.buffer("foo bar foo baz foo")
    local Occurrence = require("occurrence.Occurrence")
    local api = require("occurrence.api")
    local occurrence = Occurrence.get(bufnr)

    local result = api.cursors.callback(occurrence, nil)

    assert.is_false(result)
    assert
      .spy(notify_stub)
      .was_called_with(match.is_match("nvim_mcursor"), vim.log.levels.ERROR, { title = "Occurrence" })
  end)
end)

describe("mcursor", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    bufnr = nil
  end)

  describe(".is_supported", function()
    it("reflects whether vim.api.nvim_mcursor exists", function()
      -- Indexed by string in the adapter, so this doubles as a check
      -- that the running Neovim actually implements the API we depend on.
      assert.equals(vim.api["nvim_mcursor"] ~= nil, mcursor.is_supported())
    end)
  end)

  if not mcursor.is_supported() then
    it("requires nvim_mcursor", function()
      pending("requires nvim_mcursor")
    end)
    return
  end

  describe(".add", function()
    it("moves the window cursor to the primary and adds the rest as native cursors", function()
      bufnr = util.buffer("foo bar foo baz foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      mcursor.clear()

      local a = Location.new(0, 0)
      local b = Location.new(0, 8)
      local c = Location.new(0, 16)

      mcursor.add({ a, b, c })

      -- Window cursor took the location under the original cursor (the primary).
      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      -- The remaining two locations became extra native cursors.
      assert.equals(2, mcursor.count())
    end)

    it("picks the nearest location as primary when none is exactly under the cursor", function()
      bufnr = util.buffer("foo bar foo baz foo")
      vim.api.nvim_win_set_cursor(0, { 1, 100 }) -- clamped by nvim to the last column; nearest to `b`
      mcursor.clear()

      local a = Location.new(0, 8)
      local b = Location.new(0, 16)

      mcursor.add({ a, b })

      assert.same({ 1, 16 }, vim.api.nvim_win_get_cursor(0))
      assert.equals(1, mcursor.count())
    end)

    it("dedupes locations before splitting primary from the rest", function()
      bufnr = util.buffer("foo bar foo baz foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      mcursor.clear()

      local a = Location.new(0, 0)
      local dup = Location.new(0, 0)
      local b = Location.new(0, 8)

      mcursor.add({ a, dup, b })

      assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
      -- Only `b` remains after dedupe and removing the primary.
      assert.equals(1, mcursor.count())
    end)

    it("resolves opts.primary against the original list, not the deduped one", function()
      bufnr = util.buffer("foo bar foo baz foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      mcursor.clear()

      local a = Location.new(0, 0)
      local dup = Location.new(0, 0)
      local b = Location.new(0, 8)

      -- `b` is index 3 of the input but index 2 after dedupe.
      mcursor.add({ a, dup, b }, { primary = 3 })

      assert.same({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
      assert.equals(1, mcursor.count())
    end)

    it("does nothing for an empty location list", function()
      bufnr = util.buffer("foo bar foo baz foo")
      mcursor.clear()

      mcursor.add({})

      assert.equals(0, mcursor.count())
    end)
  end)

  describe(".add follow", function()
    it("feeds 1q= when follow is requested and extra cursors exist", function()
      bufnr = util.buffer("foo bar foo baz foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      mcursor.clear()
      local feed = stub(vim.api, "nvim_feedkeys")

      mcursor.add({ Location.new(0, 0), Location.new(0, 8) }, { follow = true })
      assert.spy(feed).was_called_with("1q=", "n", false)

      feed:clear()
      mcursor.clear()
      mcursor.add({ Location.new(0, 0) }, { follow = true })
      assert.spy(feed).was_not_called()

      feed:clear()
      mcursor.clear()
      mcursor.add({ Location.new(0, 0), Location.new(0, 8) }, { follow = false })
      assert.spy(feed).was_not_called()
      feed:revert()
    end)
  end)

  describe(".count and .clear", function()
    it("clears all extra cursors", function()
      bufnr = util.buffer("foo bar foo baz foo")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      mcursor.add({ Location.new(0, 0), Location.new(0, 8), Location.new(0, 16) })
      assert.equals(2, mcursor.count())

      mcursor.clear()
      assert.equals(0, mcursor.count())
    end)
  end)
end)
