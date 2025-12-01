local assert = require("luassert")
local spy = require("luassert.spy")

local function unload_occurrence_modules()
  require("occurrence").reset() -- Reset twice; once before reload, and...
  package.loaded["plugin.occurrence"] = nil
  ---@diagnostic disable-next-line: undefined-field
  local module_name_pattern = vim.pesc("occurrence")
  for pack, _ in pairs(package.loaded) do
    if string.find(pack, "^" .. module_name_pattern) then
      package.loaded[pack] = nil
    end
  end
end

-- Test the plugin entry point
describe("plugin occurrence", function()
  describe("entry point", function()
    before_each(unload_occurrence_modules)

    it("loads without error", function()
      assert.is_nil(package.loaded["plugin.occurrence"])
      assert.has_no.errors(function()
        require("plugin.occurrence")
      end)
      assert.is_not_nil(package.loaded["plugin.occurrence"])
    end)
  end)

  describe("lazy loading", function()
    before_each(unload_occurrence_modules)

    it("returns a table", function()
      local plugin = require("occurrence")
      assert.is_table(plugin)
    end)

    it("has metatable for lazy loading", function()
      local plugin = require("occurrence")
      local mt = getmetatable(plugin)
      assert.is_not_nil(mt)
      assert.is_function(mt.__index)
    end)

    it("metatable returns functions for occurrence methods", function()
      local plugin = require("occurrence")
      local mt = getmetatable(plugin)

      -- Should return a function when accessing unknown keys
      local result = mt.__index(plugin, "mark")
      assert.is_function(result)
    end)

    it("metatable errors on unknown keys", function()
      local plugin = require("occurrence")
      local mt = getmetatable(plugin)

      assert.has_error(function()
        mt.__index(plugin, "non_existent_method")
      end, "Missing occurrence API function: non_existent_method")
    end)

    it("lazy loads config", function()
      local plugin = require("occurrence")

      -- occurrence.Config should not be loaded yet
      assert.is_nil(package.loaded["occurrence.Config"])

      -- Accessing setup should return a function that loads occurrence.Config
      assert.is_function(plugin.setup)
      assert.is_function(plugin.reset)

      -- accessing still should not load occurrence.Config yet
      assert.is_nil(package.loaded["occurrence.Config"])

      assert.has_no.errors(function()
        plugin.setup({})
      end)

      -- Now occurrence.Config should be loaded
      assert.is_not_nil(package.loaded["occurrence.Config"])
    end)

    it("lazy loads occurrence module methods", function()
      local plugin = require("occurrence")

      -- occurrence core should not be loaded yet
      assert.is_nil(package.loaded["occurrence.Ocurrence"])

      -- Accessing mark should return a function that loads occurrence core
      assert.is_function(plugin.mark)

      assert.has_no.errors(function()
        plugin.mark()
      end)

      -- Now occurrence should be loaded
      assert.is_not_nil(package.loaded["occurrence.Occurrence"])
    end)
  end)

  describe("reset", function()
    before_each(unload_occurrence_modules)

    it("exposes reset function", function()
      assert.is_function(require("occurrence").reset)
    end)

    it("resets occurrence state", function()
      local Occurrence = require("occurrence.Occurrence")
      local reset_spy = spy.on(Occurrence, "del")
      assert.spy(reset_spy).was_not_called()

      require("occurrence").reset()
      assert.spy(reset_spy).was_called()

      reset_spy:revert()
    end)
  end)

  describe("setup", function()
    before_each(unload_occurrence_modules)

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
          operators = { x = "delete" },
        })
      end)
    end)

    it("can be called multiple times", function()
      assert.has_no.errors(function()
        local occurrence = require("occurrence")
        occurrence.setup({})
        occurrence.setup({ operators = { x = "delete" } })
        occurrence.setup({})
      end)
    end)

    it("creates valid config object", function()
      local Config = require("occurrence.Config")
      local config_spy = spy.on(Config, "new")

      local test_opts = {
        operators = { c = "change" },
      }

      require("occurrence").setup(test_opts)

      assert.spy(config_spy).was_called_with(test_opts)
      config_spy:revert()
    end)
  end)

  describe("auto setup", function()
    before_each(function()
      unload_occurrence_modules()
    end)

    after_each(function()
      vim.g.occurrence_auto_setup = nil
    end)

    it("sets up default keymaps", function()
      assert.is_nil(vim.g.occurrence_auto_setup)
      require("plugin.occurrence")
      assert.is_not_nil(package.loaded["plugin.occurrence"])

      local api = require("occurrence.api")

      -- Check that a default keymap is not set
      local mappings = vim.api.nvim_get_keymap("n")
      local found = false
      for _, map in ipairs(mappings) do
        if map.lhs == api.mark.default_global_key and map.rhs == api.mark.plug then
          found = true
          break
        end
      end

      assert.is_true(
        found,
        string.format("Keymap %s should be set after loading the plugin when auto setup is enabled", api.mark.plug)
      )
    end)

    describe("vim.g.occurrence_auto_setup = true", function()
      setup(function()
        vim.g.occurrence_auto_setup = true
      end)

      teardown(function()
        vim.g.occurrence_auto_setup = nil
      end)

      it("sets up default keymaps", function()
        assert.is_true(vim.g.occurrence_auto_setup)
        require("plugin.occurrence")
        assert.is_not_nil(package.loaded["plugin.occurrence"])

        local api = require("occurrence.api")

        -- Check that a default keymap is not set
        local mappings = vim.api.nvim_get_keymap("n")
        local found = false
        for _, map in ipairs(mappings) do
          if map.lhs == api.mark.default_global_key and map.rhs == api.mark.plug then
            found = true
            break
          end
        end

        assert.is_true(
          found,
          string.format("Keymap %s should be set after loading the plugin when auto setup is enabled", api.mark.plug)
        )
      end)
    end)

    describe("vim.g.occurrence_auto_setup = false", function()
      setup(function()
        vim.g.occurrence_auto_setup = false
      end)

      teardown(function()
        vim.g.occurrence_auto_setup = nil
      end)

      it("does not set up default keymaps when false", function()
        assert.is_false(vim.g.occurrence_auto_setup)
        require("plugin.occurrence")
        assert.is_not_nil(package.loaded["plugin.occurrence"])

        local api = require("occurrence.api")

        -- Check that a default keymap is not set
        local mappings = vim.api.nvim_get_keymap("n")
        local found = false
        for _, map in ipairs(mappings) do
          if map.lhs == api.mark.default_global_key and map.rhs == api.mark.plug then
            found = true
            break
          end
        end

        assert.is_false(
          found,
          string.format(
            "Keymap %s should not be set after loading the plugin when auto setup is disabled",
            api.mark.plug
          )
        )
      end)
    end)
  end)
end)
