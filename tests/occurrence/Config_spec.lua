local assert = require("luassert")
local spy = require("luassert.spy")
local match = require("luassert.match")
local Config = require("occurrence.Config")

describe("Config", function()
  describe("config.new validation", function()
    it("validates valid options", function()
      local valid_opts = {
        actions = {
          n = { go = "activate_preset_with_cursor_word" },
          v = { go = "activate_preset_with_selection" },
          o = { o = "modify_operator_pending" },
        },
        operators = {
          c = "change",
          d = "delete",
        },
        preset_actions = {
          n = { n = "goto_next_mark" },
          v = { go = "mark_selection" },
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
      local conf2 = Config.new({ actions = "invalid_type" })
      assert.spy(vim.notify).was_called_with(match.has_match("actions must be a table"), vim.log.levels.WARN, match._)
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
      assert.equals("activate_preset_with_search_or_cursor_word", conf1:actions().n.go)
      assert.equals("activate_preset_with_search_or_cursor_word", conf2:actions().n.go)
      assert.equals("activate_preset_with_search_or_cursor_word", conf3:actions().n.go)

      -- restore original notify
      vim.notify = original_notify
    end)
  end)

  describe("config.new", function()
    it("creates config with default values when no options provided", function()
      local conf = Config.new()

      assert.is_table(conf)
      assert.equals("activate_preset_with_search_or_cursor_word", conf:actions().n.go)
      assert.equals("activate_preset_with_selection", conf:actions().v.go)
      assert.equals("modify_operator_pending", conf:actions().o.o)
      assert.equals("modify_operator_pending_linewise", conf:actions().o.oo)
    end)

    it("creates config with nil options", function()
      local conf = Config.new(nil)

      assert.is_table(conf)
      assert.equals("activate_preset_with_search_or_cursor_word", conf:actions().n.go)
      assert.equals("activate_preset_with_selection", conf:actions().v.go)
      assert.equals("modify_operator_pending", conf:actions().o.o)
    end)

    it("overrides defaults with provided options", function()
      local opts = {
        actions = {
          n = { gn = "mark_cursor_word" },
          v = { gv = "mark_selection" },
        },
        operators = {
          p = false,
          y = "yank",
        },
        preset_actions = {
          n = { ["<Esc>"] = false },
        },
      }

      local conf = Config.new(opts)

      assert.equals("mark_cursor_word", conf:actions().n.gn)
      assert.equals("mark_selection", conf:actions().v.gv)
      assert.equals(false, conf:operators().p)
      assert.equals("yank", conf:operators().y)
      assert.equals(false, conf:preset_actions().n["<Esc>"])
    end)

    it("passes through an existing config", function()
      local opts = {
        actions = {
          n = { gn = "mark_cursor_word" },
        },
      }

      local conf1 = Config.new(opts)
      local conf2 = Config.new(conf1)

      assert.equals(conf1, conf2)
      assert.equals("mark_cursor_word", conf2:actions().n.gn)
      assert.equals("activate_preset_with_selection", conf2:actions().v.go) -- default
      assert.equals("modify_operator_pending", conf2:actions().o.o) -- default
    end)
  end)

  describe("default configuration values", function()
    it("has correct action defaults", function()
      local conf = Config.new()

      assert.equals("activate_preset_with_search_or_cursor_word", conf:actions().n.go)
      assert.equals("activate_preset_with_selection", conf:actions().v.go)
      assert.equals("modify_operator_pending", conf:actions().o.o)
    end)

    it("has correct operator defaults", function()
      local conf = Config.new()

      assert.equals("change", conf:operators().c)
      assert.equals("delete", conf:operators().d)
      assert.equals("yank", conf:operators().y)
    end)

    it("preserves option types correctly", function()
      local opts = {
        operators = {
          p = false,
          y = "yank",
        },
      }

      local conf = Config.new(opts)

      assert.is_boolean(conf:operators().p)
      assert.is_string(conf:operators().y)
      assert.is_table(conf:actions())
    end)

    it("handles empty options table", function()
      local conf = Config.new({})

      -- Should use all defaults
      assert.equals("activate_preset_with_search_or_cursor_word", conf:actions().n.go)
      assert.equals("activate_preset_with_selection", conf:actions().v.go)
      assert.equals("modify_operator_pending", conf:actions().o.o)
      assert.equals("change", conf:operators().c)
      assert.equals("deactivate", conf:preset_actions().n["<Esc>"])
    end)
  end)
end)
