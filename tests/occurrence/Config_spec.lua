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
      }

      assert.has_no.errors(function()
        Config.new(valid_opts)
      end)
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

      ---@diagnostic disable-next-line: missing-fields
      local conf4 = Config.new({ operators = { test = {} } })
      assert.spy(vim.notify).was_called_with(match.has_match("method: expected string"), vim.log.levels.WARN, match._)
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      -- Should still create configs with defaults
      assert.is_table(conf1)
      assert.is_table(conf2)
      assert.is_table(conf3)
      assert.is_table(conf4)
    end)
  end)

  describe("config.new", function()
    it("creates config with default values when no options provided", function()
      local conf = Config.new()
      local defaults = Config.default()
      assert.is_same(defaults.operators, conf:operators())
      assert.equals(defaults.default_keymaps, conf.default_keymaps)
    end)

    it("creates config with nil options", function()
      local conf = Config.new(nil)
      local defaults = Config.default()
      assert.is_same(defaults.operators, conf:operators())
      assert.equals(defaults.default_keymaps, conf.default_keymaps)
    end)

    it("overrides defaults with provided options", function()
      local opts = {
        operators = {
          p = "other",
          y = "fake",
        },
        default_keymaps = false,
      }

      local defaults = Config.default()
      local conf = Config.new(opts)

      assert.is_not_same(defaults.operators, conf:operators())
      assert.is_same(vim.tbl_deep_extend("force", defaults.operators, opts.operators), conf:operators())
      assert.is_not_same(defaults.default_keymaps, conf.default_keymaps)
      assert.equals(false, conf.default_keymaps)
    end)

    it("passes through an existing config", function()
      local opts = {
        operators = {
          x = "delete",
        },
      }

      local conf1 = Config.new(opts)
      local conf2 = Config.new(conf1)

      assert.equals(conf1, conf2)
    end)

    it("has correct operator defaults", function()
      local conf = Config.new()

      assert.equals("change", conf:operators().c)
      assert.equals("delete", conf:operators().d)
      assert.equals("yank", conf:operators().y)
    end)
  end)

  describe("Config:get_action_config", function()
    it("returns nil for unsupported actions", function()
      local conf = Config.new()
      assert.is_nil(conf:get_action_config("nonexistent_action"))
    end)

    it("resolves builtin actions", function()
      local conf = Config.new()

      local action =
        assert(conf:get_action_config("deactivate"), "Expected action config for 'deactivate' in normal mode")
      assert.is_function(action.callback)
      assert.is_string(action.desc)
      assert.equals("preset", action.type)
    end)
  end)

  describe("Config:get_operator_config", function()
    it("returns nil for unsupported operators", function()
      local conf = Config.new()
      assert.is_nil(conf:get_operator_config("nonexistent_operator"))
    end)

    it("returns nil for aliased to unsupported operators", function()
      local opts = {
        operators = {
          x = "nonexistent_operator",
        },
      }
      local conf = Config.new(opts)
      assert.is_nil(conf:get_operator_config("x"))
    end)

    it("returns builtin operator configs", function()
      local conf = Config.new()
      local op = assert(conf:get_operator_config("delete"), "Expected operator config for 'p'")
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

    it("returns default operator config when none specified", function()
      local conf = Config.new({
        operators = {
          custom = true,
        },
      })
      local op = assert(conf:get_operator_config("custom"), "Expected operator config for 'change'")
      assert.equals("visual_feedkeys", op.method)
      assert.is_false(op.uses_register)
      assert.is_true(op.modifies_text)
    end)
  end)

  describe("Config:operator_is_supported", function()
    it("returns false for unsupported operators", function()
      local conf = Config.new()
      assert.is_false(conf:operator_is_supported("nonexistent_operator"))
    end)

    it("returns true for supported builtin operators", function()
      local conf = Config.new()
      assert.is_true(conf:operator_is_supported("change"))
      assert.is_true(conf:operator_is_supported("delete"))
      assert.is_true(conf:operator_is_supported("yank"))
    end)

    it("returns true for supported aliased operators", function()
      local opts = {
        operators = {
          x = "delete",
        },
      }
      local conf = Config.new(opts)
      assert.is_true(conf:operator_is_supported("x"))
    end)

    it("returns true for supported custom operators", function()
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
      assert.is_true(conf:operator_is_supported("custom"))
    end)

    it("returns false for disabled operators", function()
      local opts = {
        operators = {
          delete = false,
        },
      }
      local conf = Config.new(opts)
      assert.is_false(conf:operator_is_supported("delete"))
    end)

    it("returns false for aliased disabled operators", function()
      local opts = {
        operators = {
          x = "delete",
          delete = false,
        },
      }
      local conf = Config.new(opts)
      assert.is_false(conf:operator_is_supported("x"))
    end)
  end)

  describe("Config:wrap_action", function()
    it("wraps table actions", function()
      local action = {
        call = function()
          return "called"
        end,
      }
      setmetatable(action, {
        __call = function(self)
          return self.call()
        end,
      })

      local wrapped = Config.new():wrap_action(action)

      assert.is_function(wrapped)
      assert.equals("called", wrapped())
    end)

    it("wraps functions", function()
      local func = function()
        return "test"
      end
      local wrapped = Config.new():wrap_action(func)
      assert.equals("test", wrapped())
    end)

    it("resolves builtin action strings", function()
      local str = "deactivate"
      local deactivate_spy = spy.on(require("occurrence.actions").deactivate, "callback")
      local wrapped = Config.new():wrap_action(str)
      wrapped()
      assert.spy(deactivate_spy).was_called()
      deactivate_spy:revert()
    end)
  end)
end)
