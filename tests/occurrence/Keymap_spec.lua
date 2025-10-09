local assert = require("luassert")
local util = require("tests.util")
local Keymap = require("occurrence.Keymap")

describe("Keymap", function()
  local bufnr

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    bufnr = nil
  end)

  describe(".new", function()
    it("creates a Keymap instance for the given buffer", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      assert.equals(bufnr, km.buffer)
      assert.is_function(km.set)
      assert.is_function(km.is_active)
      assert.is_function(km.add)
      assert.is_function(km.dispose)
      assert.is_function(km.is_disposed)
    end)

    it("creates a Keymap instance for the current buffer if no buffer is given", function()
      local buf = util.buffer()
      local km = Keymap.new()
      assert.equals(buf, km.buffer)
    end)

    it("throws an error if the given buffer is invalid", function()
      assert.has_error(function()
        Keymap.new(99999)
      end, "Invalid buffer: 99999")
    end)
  end)

  describe(":set", function()
    it("sets a keymap in the buffer", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      km:set("n", "x", "<Nop>", { desc = "Disable x" })
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local found = false
      for _, map in ipairs(mappings) do
        if map.lhs == "x" and map.desc == "Disable x" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("dispose", function()
    it("removes all keymaps set by the Keymap instance", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      km:set("n", "x", "<Nop>")
      km:set("n", "y", "<Nop>")
      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local found_x, found_y = false, false
      for _, map in ipairs(mappings) do
        if map.lhs == "x" then
          found_x = true
        elseif map.lhs == "y" then
          found_y = true
        end
      end
      assert.is_true(found_x)
      assert.is_true(found_y)
      assert.is_true(km:is_active())
      assert.is_false(km:is_disposed())
      km:dispose()
      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      found_x, found_y = false, false
      for _, map in ipairs(mappings) do
        if map.lhs == "x" then
          found_x = true
        elseif map.lhs == "y" then
          found_y = true
        end
      end
      assert.is_false(found_x)
      assert.is_false(found_y)
      assert.is_true(km:is_disposed())
      assert.is_false(km:is_active())
    end)

    it("makes the Keymap instance unusable", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      km:set("n", "x", "<Nop>")
      km:dispose()
      assert.has_error(function()
        km:set("n", "y", "<Nop>")
      end, "Cannot use a disposed Keymap")
    end)
  end)

  describe(":is_active", function()
    it("returns false if the Keymap has no active keymaps", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      assert.is_false(km:is_active())
    end)

    it("returns true if the Keymap has active keymaps", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      assert.is_false(km:is_active())
      km:set("n", "x", "<Nop>")
      assert.is_true(km:is_active())
    end)

    it("returns false if the Keymap is disposed", function()
      bufnr = util.buffer()
      local km = Keymap.new(bufnr)
      assert.is_false(km:is_active())
      km:set("n", "x", "<Nop>")
      assert.is_true(km:is_active())
      km:dispose()
      assert.is_false(km:is_active())
    end)
  end)
end)
