local assert = require("luassert")
local spy = require("luassert.spy")
local match = require("luassert.match")
local Config = require("occurrence.Config")

describe("Config", function()
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
        Config.new(valid_opts)
      end)
    end)

    it("handles invalid options gracefully with warning", function()
      -- mock vim.notify to capture warnings
      local original_notify = vim.notify
      vim.notify = spy.new(function() end)

      -- These should warn but not error (based on log.warn_once usage)
      local conf1 = Config.new({ invalid_option = "value" })
      assert.spy(vim.notify).was_called_with(match.has_match("invalid_option"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: assign-type-mismatch
      local conf2 = Config.new({ keymap = "invalid_type" })
      assert.spy(vim.notify).was_called_with(match.has_match("keymap must be a table"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: param-type-mismatch
      local conf3 = Config.new("not_a_table")
      assert.spy(vim.notify).was_called_with(match.has_match("opts must be a table"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      -- Should still create configs with defaults
      assert.is_table(conf1)
      assert.is_table(conf2)
      assert.is_table(conf3)
      assert.equals("go", conf1:keymap().normal)
      assert.equals("go", conf2:keymap().normal)
      assert.equals("go", conf3:keymap().normal)

      -- restore original notify
      vim.notify = original_notify
    end)
  end)

  describe("config.new", function()
    it("creates config with default values when no options provided", function()
      local conf = Config.new()

      assert.is_table(conf)
      assert.equals("go", conf:keymap().normal)
      assert.equals("go", conf:keymap().visual)
      assert.equals("o", conf:keymap().operator_pending)
      assert.equals(true, conf:search().enabled)
      assert.is_nil(conf:search().normal)
    end)

    it("creates config with nil options", function()
      local conf = Config.new(nil)

      assert.is_table(conf)
      assert.equals("go", conf:keymap().normal)
      assert.equals("go", conf:keymap().visual)
      assert.equals("o", conf:keymap().operator_pending)
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

      local conf = Config.new(opts)

      assert.equals("gn", conf:keymap().normal)
      assert.equals("gv", conf:keymap().visual)
      assert.equals("gp", conf:keymap().operator_pending)
      assert.equals(false, conf:search().enabled)
      assert.equals("gs", conf:search().normal)
    end)

    it("passes through an existing config", function()
      local opts = {
        keymap = {
          normal = "gn",
        },
      }

      local conf1 = Config.new(opts)
      local conf2 = Config.new(conf1)

      assert.equals(conf1, conf2)
      assert.equals("gn", conf2:keymap().normal)
      assert.equals("go", conf2:keymap().visual) -- default
      assert.equals("o", conf2:keymap().operator_pending) -- default
    end)
  end)

  describe("default configuration values", function()
    it("has correct keymap defaults", function()
      local conf = Config.new()

      assert.equals("go", conf:keymap().normal)
      assert.equals("go", conf:keymap().visual)
      assert.equals("o", conf:keymap().operator_pending)
    end)

    it("has correct search defaults", function()
      local conf = Config.new()

      assert.equals(true, conf:search().enabled)
      assert.is_nil(conf:search().normal)
    end)

    it("preserves option types correctly", function()
      local opts = {
        search = {
          enabled = false,
          normal = "search_key",
        },
      }

      local conf = Config.new(opts)

      assert.is_boolean(conf:search().enabled)
      assert.is_string(conf:search().normal)
      assert.is_table(conf:keymap())
    end)

    it("handles empty options table", function()
      local conf = Config.new({})

      -- Should use all defaults
      assert.equals("go", conf:keymap().normal)
      assert.equals("go", conf:keymap().visual)
      assert.equals("o", conf:keymap().operator_pending)
      assert.equals(true, conf:search().enabled)
      assert.is_nil(conf:search().normal)
    end)
  end)
end)
