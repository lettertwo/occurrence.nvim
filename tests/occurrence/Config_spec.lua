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
        keymaps = {
          ["<Tab>"] = "next",
          ["n"] = false,
        },
        operators = {
          c = "change",
          d = "delete",
        },
        default_keymaps = true,
      }

      assert.has_no.errors(function()
        Config.new(valid_opts)
      end)
      assert.spy(vim.notify).was_not_called()
    end)

    it("validates keymaps with custom KeymapConfig", function()
      local valid_opts = {
        keymaps = {
          ["<leader>x"] = {
            mode = "n",
            callback = function() end,
            desc = "Custom action",
          },
        },
      }

      assert.has_no.errors(function()
        Config.new(valid_opts)
      end)
      assert.spy(vim.notify).was_not_called()
    end)

    it("rejects invalid keymap values", function()
      ---@diagnostic disable-next-line: assign-type-mismatch
      local invalid_opts = {
        keymaps = {
          ["n"] = 123, -- Invalid type
        },
      }

      Config.new(invalid_opts)
      assert
        .spy(vim.notify)
        .was_called_with(match.has_match("keymap value"), vim.log.levels.WARN, { title = "Occurrence" })
    end)

    it("handles invalid options gracefully with warning", function()
      local conf1 = Config.new({ invalid_option = "value" })
      assert
        .spy(vim.notify)
        .was_called_with(match.has_match("unknown option"), vim.log.levels.WARN, { title = "Occurrence" })
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: assign-type-mismatch
      local conf2 = Config.new({ operators = "invalid_type" })
      assert
        .spy(vim.notify)
        .was_called_with(match.has_match("operators: expected table"), vim.log.levels.WARN, { title = "Occurrence" })
      ---@diagnostic disable-next-line: undefined-field
      vim.notify:clear()

      ---@diagnostic disable-next-line: param-type-mismatch
      local conf3 = Config.new("not_a_table")
      assert
        .spy(vim.notify)
        .was_called_with(match.has_match("opts: expected table"), vim.log.levels.WARN, { title = "Occurrence" })
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

    it("clears default keymaps when default_keymaps = false", function()
      local opts = {
        default_keymaps = false,
      }

      local defaults = Config.default()
      local conf = Config.new(opts)

      assert.equals(false, conf.default_keymaps)
      -- keymaps should be empty when default_keymaps = false
      assert.same({}, conf.keymaps)
      -- But defaults should have keymaps
      assert.not_same({}, defaults.keymaps)
    end)

    it("allows custom keymaps when default_keymaps = false", function()
      local custom_callback = function() end
      local opts = {
        default_keymaps = false,
        keymaps = {
          ["<Tab>"] = "next",
          ["<leader>x"] = {
            callback = custom_callback,
          },
        },
      }

      local conf = Config.new(opts)

      assert.equals(false, conf.default_keymaps)
      -- Should have only the custom keymaps
      assert.equals(2, vim.tbl_count(conf.keymaps))
      assert.equals("next", conf.keymaps["<Tab>"])
      assert.equals(custom_callback, conf.keymaps["<leader>x"].callback)
      -- Default keymaps should not be present
      assert.is_nil(conf.keymaps["n"])
      assert.is_nil(conf.keymaps["ga"])
    end)

    it("passes through an existing config", function()
      local opts = {
        default_operators = false,
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
      assert.same(require("occurrence.api").delete, op)
    end)

    it("returns builtin operator config by name", function()
      local conf = Config.new()
      local op = assert(conf:get_operator_config("delete"), "Expected operator config for 'delete'")
      assert.same(require("occurrence.api").delete, op)
    end)

    it("returns custom operator config by name", function()
      local custom_op = {
        operator = function() end,
      }
      local conf = Config.new({
        operators = {
          custom = custom_op,
        },
      })
      local op = assert(conf:get_operator_config("custom"), "Expected operator config for 'delete'")
      assert.same(custom_op, op)
    end)

    it("returns the correct operator config for aliased builtin operators", function()
      local opts = {
        operators = {
          x = "delete",
        },
      }
      local conf = Config.new(opts)
      local op = assert(conf:get_operator_config("x"), "Expected operator config for 'x'")
      assert.same(require("occurrence.api").delete, op)
    end)

    it("returns the correct operator config for aliased custom operators", function()
      local custom_op = {
        operator = function() end,
      }
      local opts = {
        operators = {
          custom = custom_op,
          x = "custom",
        },
      }
      local conf = Config.new(opts)
      local op = assert(conf:get_operator_config("x"), "Expected custom operator config for 'x'")
      assert.same(custom_op, op)
    end)

    it("returns custom operator configs", function()
      local custom_op = {
        operator = function() end,
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

    it("prevents operator alias loops", function()
      local opts = {
        operators = {
          a = "b",
          b = "custom",
          custom = "a",
        },
      }
      local conf = Config.new(opts)
      assert.errors(function()
        conf:get_operator_config("a")
      end)
      assert.errors(function()
        conf:get_operator_config("b")
      end)
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

  describe("Config:get_keymap_config", function()
    it("returns nil for unsupported API", function()
      local conf = Config.new()
      assert.is_nil(conf:get_keymap_config("nonexistent_api"))
    end)

    it("returns keymap config by key", function()
      local conf = Config.new()
      local api = assert(conf:get_keymap_config("ga"), "Expected API config for 'ga'")
      assert.same(require("occurrence.api").mark, api)
    end)

    it("returns keymap config by name", function()
      local conf = Config.new()
      local api = assert(conf:get_keymap_config("mark"), "Expected API config for 'mark'")
      assert.same(require("occurrence.api").mark, api)
    end)

    it("returns nil for explicitly disabled keymaps", function()
      local opts = {
        keymaps = {
          ["n"] = false,
        },
      }
      local conf = Config.new(opts)
      assert.is_nil(conf:get_keymap_config("n"))
      local default_config = Config.new()
      assert.not_nil(default_config:get_keymap_config("n"))
    end)

    it("returns the correct keymap config for aliased keymaps", function()
      local opts = {
        keymaps = {
          ["<Tab>"] = "next",
        },
      }
      local conf = Config.new(opts)
      local api = assert(conf:get_keymap_config("<Tab>"), "Expected API config for '<Tab>'")
      assert.same(require("occurrence.api").next, api)
    end)

    it("returns custom KeymapConfig with callback", function()
      local custom_callback = function() end
      local custom_action = {
        callback = custom_callback,
        desc = "Custom action",
      }
      local opts = {
        keymaps = {
          ["<leader>x"] = custom_action,
        },
      }
      local conf = Config.new(opts)
      local api = assert(conf:get_keymap_config("<leader>x"), "Expected action config for '<leader>x'")
      assert.equals(custom_action, api)
      assert.equals(custom_callback, api.callback)
    end)

    it("returns nil for explicitly disabled keymaps", function()
      local opts = {
        keymaps = {
          ["disabled"] = false,
        },
      }
      local conf = Config.new(opts)
      assert.is_nil(conf:get_keymap_config("disabled"))
      assert.is_false(conf:keymap_is_supported("disabled"))
    end)
  end)

  describe("Config:keymap_is_supported", function()
    it("returns false for unsupported keymaps", function()
      local conf = Config.new()
      assert.is_false(conf:keymap_is_supported("nonexistent_api"))
    end)

    it("returns true for supported API names and their default keys", function()
      local conf = Config.new()
      assert.is_true(conf:keymap_is_supported("mark"))
      assert.is_true(conf:keymap_is_supported("unmark"))
      assert.is_true(conf:keymap_is_supported("deactivate"))
      assert.is_true(conf:keymap_is_supported("ga"))
      assert.is_true(conf:keymap_is_supported("gx"))
      assert.is_true(conf:keymap_is_supported("<Esc>"))
    end)
  end)
end)
