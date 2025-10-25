local assert = require("luassert")
local stub = require("luassert.stub")
local match = require("luassert.match")
local Config = require("occurrence.Config")

describe("Config", function()
  local notify_stub

  before_each(function()
    -- stub out notify to avoid polluting test output
    notify_stub = stub(vim, "notify")
  end)

  after_each(function()
    notify_stub:revert()
  end)

  describe("config.new validation", function()
    it("validates valid options", function()
      local valid_opts = {
        operators = {
          c = "change",
          d = "delete",
        },
        default_keymaps = true,
        on_activate = setmetatable({}, {
          __call = function() end,
        }),
      }

      assert.has_no.errors(function()
        Config.new(valid_opts)
      end)
      assert.spy(vim.notify).was_not_called_with(match._, vim.log.levels.WARN, match._)
    end)

    it("handles invalid options gracefully with warning", function()
      local conf1 = Config.new({ invalid_option = "value" })
      assert.spy(vim.notify).was_called_with(match.has_match("unknown option"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: assign-type-mismatch
      local conf2 = Config.new({ operators = "invalid_type" })
      assert.spy(vim.notify).was_called_with(match.has_match("operators: expected table"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: param-type-mismatch
      local conf3 = Config.new("not_a_table")
      assert.spy(vim.notify).was_called_with(match.has_match("opts: expected table"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      -- Should still create configs with defaults
      assert.is_table(conf1)
      assert.is_table(conf2)
      assert.is_table(conf3)
    end)
  end)

  describe("config.new", function()
    it("creates config with default values when no options provided", function()
      local conf = Config.new()
      local defaults = Config.default()
      assert.equals(defaults.default_keymaps, conf.default_keymaps)
      assert.equals(defaults.default_operators, conf.default_operators)
      assert.same(defaults.operators, conf.operators)
    end)

    it("creates config with nil options", function()
      local conf = Config.new(nil)
      local defaults = Config.default()
      assert.equals(defaults.default_keymaps, conf.default_keymaps)
      assert.equals(defaults.default_operators, conf.default_operators)
      assert.same(defaults.operators, conf.operators)
    end)

    it("overrides defaults with provided options", function()
      local opts = {
        default_keymaps = false,
        default_operators = false,
        operators = {
          c = "change",
          d = "delete",
        },
      }

      local defaults = Config.default()
      local conf = Config.new(opts)

      assert.equals(false, conf.default_keymaps)
      assert.equals(false, conf.default_operators)
      assert.not_same(defaults.operators, conf.operators)
    end)

    it("passes through an existing config", function()
      local opts = {
        default_operators = false,
        on_activate = function() end,
      }

      local conf1 = Config.new(opts)
      local conf2 = Config.new(conf1)

      assert.equals(conf1, conf2)
    end)
  end)

  describe("Config:get_operator_config", function()
    it("returns nil for unsupported operators", function()
      local conf = Config.new()
      assert.is_nil(conf:get_operator_config("nonexistent_operator"))
    end)

    it("returns operator config by key", function()
      local conf = Config.new()
      local op = assert(conf:get_operator_config("d"), "Expected operator config for 'd'")
      assert.same(require("occurrence.operators").delete, op)
    end)

    it("returns operator config by name", function()
      local conf = Config.new()
      local op = assert(conf:get_operator_config("delete"), "Expected operator config for 'delete'")
      assert.same(require("occurrence.operators").delete, op)
    end)

    it("returns the correct operator config for aliased operators", function()
      local opts = {
        operators = {
          x = "delete",
        },
      }
      local conf = Config.new(opts)
      local op = assert(conf:get_operator_config("x"), "Expected operator config for 'p'")
      assert.same(require("occurrence.operators").delete, op)
    end)

    it("returns custom operator configs", function()
      local custom_op = {
        desc = "Custom operator",
        method = "command",
        uses_register = false,
        modifies_text = true,
      }
      local opts = {
        operators = {
          custom = custom_op,
        },
      }
      local conf = Config.new(opts)
      local op = assert(conf:get_operator_config("custom"), "Expected operator config for 'custom'")
      assert.equals(custom_op, op)
    end)
  end)

  describe("Config:operator_is_supported", function()
    it("returns false for unsupported operators", function()
      local conf = Config.new()
      assert.is_false(conf:operator_is_supported("nonexistent_operator"))
    end)

    it("returns true for supported operators and their default keys", function()
      local conf = Config.new()
      assert.is_true(conf:operator_is_supported("change"))
      assert.is_true(conf:operator_is_supported("delete"))
      assert.is_true(conf:operator_is_supported("yank"))
      assert.is_true(conf:operator_is_supported("c"))
      assert.is_true(conf:operator_is_supported("d"))
      assert.is_true(conf:operator_is_supported("y"))
    end)
  end)

  describe("Config:get_api_config", function()
    it("returns nil for unsupported API", function()
      local conf = Config.new()
      assert.is_nil(conf:get_api_config("nonexistent_api"))
    end)

    it("returns API config by key", function()
      local conf = Config.new()
      local api = assert(conf:get_api_config("ga"), "Expected API config for 'ga'")
      assert.same(require("occurrence.api").mark, api)
    end)

    it("returns API config by name", function()
      local conf = Config.new()
      local api = assert(conf:get_api_config("mark"), "Expected API config for 'mark'")
      assert.same(require("occurrence.api").mark, api)
    end)
  end)

  describe("Config:api_is_supported", function()
    it("returns false for unsupported API", function()
      local conf = Config.new()
      assert.is_false(conf:api_is_supported("nonexistent_api"))
    end)

    it("returns true for supported API names and their default keys", function()
      local conf = Config.new()
      assert.is_true(conf:api_is_supported("mark"))
      assert.is_true(conf:api_is_supported("unmark"))
      assert.is_true(conf:api_is_supported("deactivate"))
      assert.is_true(conf:api_is_supported("ga"))
      assert.is_true(conf:api_is_supported("gx"))
      assert.is_true(conf:api_is_supported("<Esc>"))
    end)
  end)
end)
