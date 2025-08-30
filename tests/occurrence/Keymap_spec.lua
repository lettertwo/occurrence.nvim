local assert = require("luassert")
local spy = require("luassert.spy")
local Keymap = require("occurrence.Keymap")

describe("Keymap", function()
  describe("Keymap.new", function()
    it("creates buffer-bound keymap", function()
      local buf = vim.api.nvim_get_current_buf()
      local keymap = Keymap.new(buf)

      assert.is_table(keymap)
      assert.equals(buf, keymap.buffer)
      assert.is_table(keymap.active_keymaps)
      assert.is_function(keymap.n)
      assert.is_function(keymap.o)
      assert.is_function(keymap.x)
      assert.is_function(keymap.reset)
    end)

    it("creates independent keymap instances", function()
      local buf1 = vim.api.nvim_get_current_buf()
      local buf2 = vim.api.nvim_create_buf(false, true)

      local keymap1 = Keymap.new(buf1)
      local keymap2 = Keymap.new(buf2)

      assert.is_not.equal(keymap1, keymap2)
      assert.equals(buf1, keymap1.buffer)
      assert.equals(buf2, keymap2.buffer)

      vim.api.nvim_buf_delete(buf2, { force = true })
    end)
  end)

  describe("Keymap.validate_mode", function()
    it("validates correct modes", function()
      assert.has_no.errors(function()
        Keymap.validate_mode("n")
      end)

      assert.has_no.errors(function()
        Keymap.validate_mode("o")
      end)

      assert.has_no.errors(function()
        Keymap.validate_mode("x")
      end)
    end)

    it("errors for invalid modes", function()
      assert.error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        Keymap.validate_mode("invalid")
      end)

      assert.error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        Keymap.validate_mode("i")
      end)

      assert.error(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        Keymap.validate_mode("")
      end)
    end)
  end)

  describe("Keymap.wrap_action", function()
    it("wraps table actions in function", function()
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

      local wrapped = Keymap.wrap_action(action)

      assert.is_function(wrapped)
      assert.equals("called", wrapped())
    end)

    it("returns functions unchanged", function()
      local func = function()
        return "test"
      end
      local wrapped = Keymap.wrap_action(func)

      assert.equals(func, wrapped)
    end)

    it("returns strings unchanged", function()
      local str = ":echo 'test'"
      local wrapped = Keymap.wrap_action(str)

      assert.equals(str, wrapped)
    end)
  end)

  describe("keymap:parse_opts", function()
    local keymap

    before_each(function()
      local buf = vim.api.nvim_get_current_buf()
      keymap = Keymap.new(buf)
    end)

    it("converts string to desc option", function()
      local opts = keymap:parse_opts("Test description")

      assert.is_table(opts)
      assert.equals("Test description", opts.desc)
      assert.equals(keymap.buffer, opts.buffer)
    end)

    it("extends table options with buffer", function()
      local opts = keymap:parse_opts({ desc = "Test", silent = true })

      assert.equals("Test", opts.desc)
      assert.is_true(opts.silent)
      assert.equals(keymap.buffer, opts.buffer)
    end)

    it("preserves existing buffer option", function()
      local different_buf = vim.api.nvim_create_buf(false, true)
      local opts = keymap:parse_opts({ desc = "test", other_opt = true })

      -- Should add the buffer from keymap
      assert.equals(keymap.buffer, opts.buffer)
      assert.equals("test", opts.desc)
      assert.is_true(opts.other_opt)

      vim.api.nvim_buf_delete(different_buf, { force = true })
    end)
  end)

  describe("mode-specific keymap methods", function()
    local keymap, buf

    before_each(function()
      buf = vim.api.nvim_get_current_buf()
      keymap = Keymap.new(buf)
    end)

    describe("keymap:n", function()
      it("sets normal mode keymap", function()
        local cb = spy.new(function() end)
        keymap:n("test_key", cb, "Test normal")

        assert.is_true(keymap.active_keymaps.n["test_key"])
        assert.spy(cb).was_not_called()

        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("test_key", true, false, true), "x", true)
        assert.spy(cb).was_called()
      end)

      it("handles string action", function()
        _G.cb = spy.new(function() end)
        keymap:n("test_key", "<cmd>lua _G.cb()<cr>", "Test command")

        assert.is_true(keymap.active_keymaps.n["test_key"])
        assert.spy(_G.cb).was_not_called()

        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("test_key", true, false, true), "x", true)
        assert.spy(_G.cb).was_called()

        _G.cb = nil
      end)

      it("handles table action", function()
        local action = {
          call = spy.new(function()
            return "test"
          end),
        }
        setmetatable(action, {
          __call = function(self)
            return self.call()
          end,
        })
        keymap:n("test_key", action, "Test action")

        assert.is_true(keymap.active_keymaps.n["test_key"])
        assert.spy(action.call).was_not_called()

        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("test_key", true, false, true), "x", true)
        assert.spy(action.call).was_called()
      end)
    end)

    describe("keymap:o", function()
      it("sets operator-pending mode keymap", function()
        local cb = spy.new(function() end)
        keymap:o("test_key", cb, "Test operator")

        assert.is_true(keymap.active_keymaps.o["test_key"])
        assert.spy(cb).was_not_called()

        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("ctest_key", true, false, true), "x", true)
        assert.spy(cb).was_called()
      end)
    end)

    describe("keymap:x", function()
      it("sets visual mode keymap", function()
        local cb = spy.new(function() end)
        keymap:x("test_key", cb, "Test visual")

        assert.is_true(keymap.active_keymaps.x["test_key"])
        assert.spy(cb).was_not_called()

        -- Enter visual mode and press the key
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v", true, false, true), "x", true)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("test_key", true, false, true), "x", true)
        assert.spy(cb).was_called()
      end)
    end)
  end)

  describe("keymap:reset", function()
    local keymap1, keymap2, buf1, buf2

    before_each(function()
      buf1 = vim.api.nvim_get_current_buf()
      buf2 = vim.api.nvim_create_buf(false, true)
      keymap1 = Keymap.new(buf1)
      keymap2 = Keymap.new(buf2)
    end)

    after_each(function()
      keymap1:reset()
      keymap2:reset()
      vim.api.nvim_buf_delete(buf2, { force = true })
    end)

    it("removes all active keymaps", function()
      -- Set multiple keymaps
      keymap1:n("test_n", function() end, "Normal test")
      keymap1:o("test_o", function() end, "Operator test")
      keymap1:x("test_x", function() end, "Visual test")

      -- Verify they're tracked
      assert.is_true(keymap1.active_keymaps.n["test_n"])
      assert.is_true(keymap1.active_keymaps.o["test_o"])
      assert.is_true(keymap1.active_keymaps.x["test_x"])

      -- Reset
      keymap1:reset()

      -- Verify tracking is cleared - accessing them should create empty tables
      assert.same({}, keymap1.active_keymaps.n)
      assert.same({}, keymap1.active_keymaps.o)
      assert.same({}, keymap1.active_keymaps.x)
    end)

    it("handles reset with no active keymaps", function()
      assert.has_no.errors(function()
        keymap1:reset()
      end)
    end)

    it("continues working after reset", function()
      keymap1:n("test_1", function() end, "Test 1")
      keymap1:reset()

      -- Should be able to set new keymaps after reset
      assert.has_no.errors(function()
        keymap1:n("test_2", function() end, "Test 2")
      end)

      assert.is_true(keymap1.active_keymaps.n["test_2"])
    end)

    it("handles multiple keymap instances independently", function()
      keymap1:n("test_key", function()
        return "buf1"
      end, "Buffer 1")
      keymap2:n("test_key", function()
        return "buf2"
      end, "Buffer 2")

      Keymap:n("test_key", function()
        return "global"
      end, "Global")

      assert.is_true(keymap1.active_keymaps.n["test_key"])
      assert.is_true(keymap2.active_keymaps.n["test_key"])
      assert.is_true(Keymap.active_keymaps.n["test_key"])

      -- Reset one shouldn't affect the other
      keymap1:reset()

      assert.same({}, keymap1.active_keymaps.n) -- empty after reset
      assert.is_true(keymap2.active_keymaps.n["test_key"])
      assert.is_true(Keymap.active_keymaps.n["test_key"])

      Keymap:reset()

      assert.same({}, keymap1.active_keymaps.n)
      assert.is_true(keymap2.active_keymaps.n["test_key"])
      assert.same({}, Keymap.active_keymaps.n)

      keymap2:reset()
      assert.same({}, keymap2.active_keymaps.n)
    end)
  end)
end)
