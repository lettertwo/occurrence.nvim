local assert = require("luassert")
local spy = require("luassert.spy")
local match = require("luassert.match")
local util = require("tests.util")
local config = require("occurrence.Config")

describe("Config", function()
  -- We can't directly test Config:validate since it's an internal method
  -- Instead we test it indirectly through config.new behavior

  describe("config.new validation", function()
    it("validates valid options", function()
      local valid_opts = {
        keymap = {
          normal = "gn",
          visual = "gv",
          operator_pending = "go",
        },
        search = {
          enabled = false,
          normal = "gs",
        },
      }

      assert.has_no.errors(function()
        config.new(valid_opts)
      end)
    end)

    it("handles invalid options gracefully with warning", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      -- These should warn but not error (based on log.warn_once usage)
      local conf1 = config.new({ invalid_option = "value" })
      assert.spy(vim.notify).was_called_with(match.has_match("invalid_option"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      local conf2 = config.new({ keymap = "invalid_type" })
      assert.spy(vim.notify).was_called_with(match.has_match("keymap must be a table"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: param-type-mismatch
      local conf3 = config.new("not_a_table")
      assert.spy(vim.notify).was_called_with(match.has_match("opts must be a table"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      -- Should still create configs with defaults
      assert.is_table(conf1)
      assert.is_table(conf2)
      assert.is_table(conf3)
      assert.equals("go", conf1.keymap.normal)
      assert.equals("go", conf2.keymap.normal)
      assert.equals("go", conf3.keymap.normal)

      -- restore original notify
      vim.notify = original_notify
    end)
  end)

  describe("config.new", function()
    it("creates config with default values when no options provided", function()
      local conf = config.new()

      assert.is_table(conf)
      assert.equals("go", conf.keymap.normal)
      assert.equals("go", conf.keymap.visual)
      assert.equals("o", conf.keymap.operator_pending)
      assert.equals(true, conf.search.enabled)
      assert.is_nil(conf.search.normal)
    end)

    it("creates config with nil options", function()
      local conf = config.new(nil)

      assert.is_table(conf)
      assert.equals("go", conf.keymap.normal)
      assert.equals("go", conf.keymap.visual)
      assert.equals("o", conf.keymap.operator_pending)
    end)

    it("overrides defaults with provided options", function()
      local opts = {
        keymap = {
          normal = "gn",
          visual = "gv",
          operator_pending = "gp",
        },
        search = {
          enabled = false,
          normal = "gs",
        },
      }

      local conf = config.new(opts)

      assert.equals("gn", conf.keymap.normal)
      assert.equals("gv", conf.keymap.visual)
      assert.equals("gp", conf.keymap.operator_pending)
      assert.equals(false, conf.search.enabled)
      assert.equals("gs", conf.search.normal)
    end)

    it("creates read-only config", function()
      local conf = config.new()

      assert.error(function()
        ---@diagnostic disable-next-line: inject-field
        conf.new_field = "value"
      end)

      assert.error(function()
        conf.keymap = {}
      end)

      assert.error(function()
        conf.keymap.normal = "new_value"
      end)

      assert.error(function()
        conf.search = {}
      end)

      assert.error(function()
        conf.search.enabled = false
      end)
    end)
  end)

  describe("default configuration values", function()
    it("has correct keymap defaults", function()
      local conf = config.new()

      assert.equals("go", conf.keymap.normal)
      assert.equals("go", conf.keymap.visual)
      assert.equals("o", conf.keymap.operator_pending)
    end)

    it("has correct search defaults", function()
      local conf = config.new()

      assert.equals(true, conf.search.enabled)
      assert.is_nil(conf.search.normal)
    end)

    it("preserves option types correctly", function()
      local opts = {
        search = {
          enabled = false,
          normal = "search_key",
        },
      }

      local conf = config.new(opts)

      assert.is_boolean(conf.search.enabled)
      assert.is_string(conf.search.normal)
      assert.is_table(conf.keymap)
    end)

    it("handles empty options table", function()
      local conf = config.new({})

      -- Should use all defaults
      assert.equals("go", conf.keymap.normal)
      assert.equals("go", conf.keymap.visual)
      assert.equals("o", conf.keymap.operator_pending)
      assert.equals(true, conf.search.enabled)
      assert.is_nil(conf.search.normal)
    end)
  end)
end)
