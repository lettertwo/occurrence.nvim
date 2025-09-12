local assert = require("luassert")
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
          actions = { n = { ["<leader>test"] = "activate_preset_with_cursor_word" } },
        })
      end)
    end)

    it("can be called multiple times", function()
      assert.has_no.errors(function()
        local occurrence = require("occurrence")
        occurrence.setup({})
        occurrence.setup({ actions = { n = { ["<leader>test"] = "activate_preset_with_cursor_word" } } })
        occurrence.setup({})
      end)
    end)

    it("creates valid config object", function()
      local Config = require("occurrence.Config")
      local config_spy = spy.on(Config, "new")

      local test_opts = {
        actions = { n = { ["<leader>test"] = "activate_preset_with_cursor_word" } },
        operators = { c = "change" },
      }

      require("occurrence").setup(test_opts)

      assert.spy(config_spy).was_called_with(test_opts)
      config_spy:revert()
    end)

    it("sets up basic keymaps with default config", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_n_spy = spy.on(Keymap, "n")
      local keymap_v_spy = spy.on(Keymap, "v")
      local keymap_o_spy = spy.on(Keymap, "o")
      assert.spy(keymap_n_spy).was_not_called()
      assert.spy(keymap_v_spy).was_not_called()
      assert.spy(keymap_o_spy).was_not_called()

      require("occurrence").setup({})
      assert.spy(keymap_n_spy).was_called()
      assert.spy(keymap_v_spy).was_called()
      assert.spy(keymap_o_spy).was_not_called()

      keymap_n_spy:revert()
      keymap_v_spy:revert()
      keymap_o_spy:revert()
    end)
  end)

  describe("action integration", function()
    it("sets up default actions", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({})

      -- The default configuration uses "activate_preset_with_search_or_cursor_word" for the "go" key
      assert.spy(keymap_spy).was_called()
      local found_go = false
      for _, call in ipairs(keymap_spy.calls) do
        if call.vals[2] == "go" then
          found_go = true
          break
        end
      end
      assert.is_true(found_go, "Should set up 'go' keymap")

      keymap_spy:revert()
    end)

    it("handles custom action mappings", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_spy = spy.on(Keymap, "n")

      require("occurrence").setup({
        actions = {
          n = {
            ["<leader>o"] = "activate_preset_with_cursor_word",
          },
        },
      })

      assert.spy(keymap_spy).was_called()
      local found_leader_o = false
      for _, call in ipairs(keymap_spy.calls) do
        if call.vals[2] == "<leader>o" then
          found_leader_o = true
          break
        end
      end
      assert.is_true(found_leader_o, "Should set up '<leader>o' keymap")

      keymap_spy:revert()
    end)

    it("handles disabled actions", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_n_spy = spy.on(Keymap, "n")

      require("occurrence").setup({
        actions = {
          n = {
            go = false, -- Disable the default "go" mapping
          },
        },
      })

      -- Should not be called with "go" since it's disabled
      for _, call in ipairs(keymap_n_spy.calls) do
        assert.is_not.equal("go", call.vals[2])
      end

      keymap_n_spy:revert()
    end)

    it("sets up visual mode actions", function()
      local Keymap = require("occurrence.Keymap")
      local keymap_v_spy = spy.on(Keymap, "v")

      require("occurrence").setup({
        actions = {
          v = {
            ["<leader>v"] = "activate_preset_with_selection",
          },
        },
      })

      assert.spy(keymap_v_spy).was_called()
      local found_leader_v = false
      for _, call in ipairs(keymap_v_spy.calls) do
        if call.vals[2] == "<leader>v" then
          found_leader_v = true
          break
        end
      end
      assert.is_true(found_leader_v, "Should set up '<leader>v' keymap")

      keymap_v_spy:revert()
    end)

    it("sets up operator-pending mode actions", function()
      local actions_config = {
        o = {
          o = "modify_operator_pending",
          oo = "modify_operator_pending_linewise",
        },
      }

      require("occurrence").setup({
        actions = actions_config,
      })

      -- Operator-pending mode keymaps are set up via autocmd, so we just verify the autocmd is created
      local autocmds = vim.api.nvim_get_autocmds({ event = "ModeChanged", pattern = "*:*o" })
      assert.is_true(#autocmds > 0, "Should create ModeChanged autocmd for operator-pending mode")
    end)
  end)
end)
