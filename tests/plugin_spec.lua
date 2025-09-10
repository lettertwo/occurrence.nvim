local assert = require("luassert")
local match = require("luassert.match")
local spy = require("luassert.spy")

-- Test the plugin entry point
describe("plugin occurrence", function()
  describe("plugin entry point", function()
    it("loads without error", function()
      assert.has_no.errors(function()
        require("plugin.occurrence")
      end)
    end)

    it("returns a table", function()
      local plugin = require("plugin.occurrence")
      assert.is_table(plugin)
    end)

    it("has metatable for lazy loading", function()
      local plugin = require("plugin.occurrence")
      local mt = getmetatable(plugin)
      assert.is_not_nil(mt)
      assert.is_function(mt.__index)
    end)

    it("metatable returns functions for occurrence methods", function()
      local plugin = require("plugin.occurrence")
      local mt = getmetatable(plugin)

      -- Should return a function when accessing unknown keys
      local result = mt.__index(plugin, "setup")
      assert.is_function(result)

      local result2 = mt.__index(plugin, "reset")
      assert.is_function(result2)
    end)

    it("lazy loads occurrence module methods", function()
      local plugin = require("plugin.occurrence")

      -- occurrence should not be loaded yet
      assert.is_nil(package.loaded["occurrence"])

      -- Accessing setup should return a function that loads occurrence
      assert.is_function(plugin.setup)
      assert.is_function(plugin.reset)

      -- accessing still should not load occurrence yet
      assert.is_nil(package.loaded["occurrence"])

      assert.has_no.errors(function()
        plugin.setup({})
      end)

      -- Now occurrence should be loaded
      assert.is_not_nil(package.loaded["occurrence"])
    end)

    it("handles invalid method names gracefully", function()
      local plugin = require("plugin.occurrence")

      -- Should still return a function even for non-existent methods
      assert.is_function(plugin.nonexistent_method)
    end)
  end)
end)

describe("occurrence module", function()
  describe("reset", function()
    it("exposes reset function", function()
      assert.is_function(require("occurrence").reset)
    end)

    it("resets keymap state", function()
      local Keymap = require("occurrence.Keymap")
      local reset_spy = spy.on(Keymap, "reset")
      assert.spy(reset_spy).was_not_called()

      require("occurrence").reset()
      assert.spy(reset_spy).was_called()

      reset_spy:revert()
    end)
  end)

  describe("setup", function()
    it("exposes setup function", function()
      assert.is_function(require("occurrence").setup)
    end)

    it("handles nil config", function()
      assert.has_no.errors(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        require("occurrence").setup(nil)
      end)
    end)

    it("handles empty config", function()
      assert.has_no.errors(function()
        require("occurrence").setup({})
      end)
    end)

    it("handles partial config", function()
      assert.has_no.errors(function()
        require("occurrence").setup({
          keymap = { normal = "<leader>test" },
        })
      end)
    end)

    it("can be called multiple times", function()
      assert.has_no.errors(function()
        local occurrence = require("occurrence")
        occurrence.setup({})
        occurrence.setup({ keymap = { normal = "<leader>test" } })
        occurrence.setup({})
      end)
    end)

    it("creates valid config object", function()
      local Config = require("occurrence.Config")
      local config_spy = spy.on(Config, "new")

      local test_opts = {
        keymap = { normal = "<leader>test" },
        search = { enabled = false },
      }

      require("occurrence").setup(test_opts)

      assert.spy(config_spy).was_called_with(test_opts)
      config_spy:revert()
    end)

    it("sets up basic keymaps with default config", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_n_spy = spy.on(Keymap, "n")
      local keymap_x_spy = spy.on(Keymap, "x")
      local keymap_o_spy = spy.on(Keymap, "o")
      assert.spy(keymap_n_spy).was_not_called()
      assert.spy(keymap_x_spy).was_not_called()
      assert.spy(keymap_o_spy).was_not_called()

      require("occurrence").setup({})
      assert.spy(keymap_n_spy).was_called()
      assert.spy(keymap_x_spy).was_called()
      assert.spy(keymap_o_spy).was_not_called()

      keymap_n_spy:revert()
      keymap_x_spy:revert()
      keymap_o_spy:revert()
    end)
  end)

  describe("search integration", function()
    it("sets up search by default", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({})

      -- TODO: Figure out how to match on the action bound to the key.

      assert.spy(keymap_spy).was_called_with(match.is_ref(Keymap), "go", match._, {
        expr = true,
        desc = "Find occurrences of search or word",
      })

      keymap_spy:revert()
    end)

    it("disables search keymap when disabled", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({
        search = { enabled = false },
      })

      -- TODO: Figure out how to match on the action bound to the key.

      assert.spy(keymap_spy).was_called_with(match.is_ref(Keymap), "go", match._, {
        expr = true,
        desc = "Find occurrences of word",
      })

      keymap_spy:revert()
    end)

    it("handles search keymap same as normal keymap", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({
        keymap = {
          normal = "<leader>o",
        },
        search = {
          enabled = true,
          normal = "<leader>o", -- Same as normal keymap
        },
      })

      assert.spy(keymap_spy).was_called_with(match.is_ref(Keymap), "<leader>o", match._, {
        expr = true,
        desc = "Find occurrences of search or word",
      })

      keymap_spy:revert()
    end)

    it("sets up search keymap when enabled with nil normal key", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({
        keymap = { normal = "<leader>o" },
        search = {
          enabled = true,
          normal = nil,
        },
      })

      assert.spy(keymap_spy).was_called_with(match.is_ref(Keymap), "<leader>o", match._, {
        expr = true,
        desc = "Find occurrences of search or word",
      })

      keymap_spy:revert()
    end)

    it("sets up search keymap with a different normal key", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({
        keymap = {
          normal = "<leader>o",
        },
        search = {
          enabled = true,
          normal = "<leader>s", -- Different from normal keymap
        },
      })

      assert.spy(keymap_spy).was_called_with(match.is_ref(Keymap), "<leader>o", match._, {
        expr = true,
        desc = "Find occurrences of word",
      })

      assert.spy(keymap_spy).was_called_with(match.is_ref(Keymap), "<leader>s", match._, {
        expr = true,
        desc = "Find occurrences of last search",
      })

      keymap_spy:revert()
    end)
  end)
end)
