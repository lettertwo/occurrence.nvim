local assert = require("luassert")
local stub = require("luassert.stub")
local util = require("tests.util")

local feedkeys = require("occurrence.feedkeys")
local plugin = require("occurrence")

local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")

describe("README examples", function()
  local bufnr
  local notify_stub

  before_each(function()
    -- stub out notify to avoid polluting test output
    notify_stub = stub(vim, "notify")
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    vim.fn.setreg("/", "")
    vim.v.hlsearch = 0
    bufnr = nil
    plugin.reset()

    notify_stub:revert()
  end)

  describe("Configuration", function()
    it("describes customizing keymaps accurately", function()
      bufnr = util.buffer({
        "This is a sample buffer.",
        "It contains several words.",
        "This is a buffer for testing occurrence plugin.",
      })
      plugin.setup({
        default_keymaps = false,
        on_activate = function(map)
          map("n", "q", "<Plug>(OccurrenceDeactivate)")
        end,
      })
      vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceMark)")
      vim.keymap.set("v", "<C-o>", "<cmd>Occurrence toggle<CR>")
      vim.keymap.set("o", "<C-o>", function()
        require("occurrence").modify_operator()
      end)

      local mappings = vim.api.nvim_get_keymap("n")
      local has_leader_o = false
      for _, map in ipairs(mappings) do
        if map.lhs == "\\o" and map.rhs == "<Plug>(OccurrenceMark)" then
          has_leader_o = true
        end
      end
      assert.is_true(has_leader_o, "'<leader>o' keymap should be set for marking occurrences")

      mappings = vim.api.nvim_get_keymap("v")
      local has_ctrl_o_v = false
      for _, map in ipairs(mappings) do
        if map.lhs == "<C-O>" and map.rhs == "<Cmd>Occurrence toggle<CR>" then
          has_ctrl_o_v = true
        end
      end
      assert.is_true(has_ctrl_o_v, "'<C-o>' keymap should be set for visual selection marking")

      mappings = vim.api.nvim_get_keymap("o")
      local has_ctrl_o_o = false
      for _, map in ipairs(mappings) do
        if map.lhs == "<C-O>" and map.rhs == nil and map.callback ~= nil then
          has_ctrl_o_o = true
        end
      end
      assert.is_true(has_ctrl_o_o, "'<C-o>' keymap should be set for operator-pending marking")

      feedkeys("<leader>o")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Two occurrences of 'This' should be marked")

      feedkeys("q")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "All marks should be cleared on q")

      feedkeys("ggv2w<C-o>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(1, #marks, "Only the first occurrence of the visual selection should be marked")

      feedkeys("q")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "All marks should be cleared on q")

      vim.api.nvim_win_set_cursor(0, { 1, 10 })
      feedkeys("d<C-o>")
      vim.wait(0) -- modify_operator is async
      feedkeys("w")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "All marks should be cleared after operator usage")

      assert.same({
        "This is a  buffer.",
        "It contains several words.",
        "This is a buffer for testing occurrence plugin.",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'This' occurrences should be deleted correctly")
    end)

    it("describes customizing occurrence mode keymaps accurately", function()
      bufnr = util.buffer({
        "This is a sample buffer.",
        "It contains several words.",
        "This buffer is for testing occurrence plugin.",
      })

      plugin.setup({
        default_keymaps = false,
        keymaps = {
          ["<Tab>"] = "next",
          ["<S-Tab>"] = "previous",
        },
        on_activate = function(map)
          -- Batch operations
          map("n", "<leader>a", function()
            assert(require("occurrence").get()):mark_all()
          end)
          map("n", "<leader>x", function()
            assert(require("occurrence").get()):unmark_all()
          end)

          -- Exit
          map("n", "q", "<Plug>(OccurrenceDeactivate)")
        end,
        operators = {
          ["c"] = "change",
          ["d"] = "delete",
          ["y"] = "yank",
          ["g?"] = false, -- Disable ROT13
          ["g~"] = false, -- Disable swap case
        },
      })

      -- Set up custom keymaps using <Plug> mappings
      vim.keymap.set({ "n", "v" }, "<leader>o", "<Plug>(OccurrenceMark)")

      -- Verify keymaps are set
      local mappings = vim.api.nvim_get_keymap("n")
      local has_leader_o = false
      for _, map in ipairs(mappings) do
        -- Default <leader> is "\"
        if map.lhs == "\\o" and map.rhs == "<Plug>(OccurrenceMark)" then
          has_leader_o = true
        end
      end
      assert.is_true(has_leader_o, "'<leader>o' keymap should be set for marking occurrences")

      feedkeys("<leader>o")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Two occurrences of 'This' should be marked")

      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local has_tab = false
      local has_stab = false
      local has_a = false
      local has_x = false
      local has_q = false
      local has_change = false
      local has_delete = false
      local has_yank = false
      local has_rot13 = false
      local has_swapcase = false
      for _, map in ipairs(mappings) do
        if map.lhs == "<Tab>" and map.desc == "Next marked occurrence" then
          has_tab = true
        end
        if map.lhs == "<S-Tab>" and map.desc == "Previous marked occurrence" then
          has_stab = true
        end
        if map.lhs == "\\a" then
          has_a = true
        end
        if map.lhs == "\\x" then
          has_x = true
        end
        if map.lhs == "q" and map.rhs == "<Plug>(OccurrenceDeactivate)" then
          has_q = true
        end
        if map.lhs == "c" then
          has_change = true
        end
        if map.lhs == "d" then
          has_delete = true
        end
        if map.lhs == "y" then
          has_yank = true
        end
        if map.lhs == "g?" then
          has_rot13 = true
        end
        if map.lhs == "g~" then
          has_swapcase = true
        end
      end
      assert.is_true(has_tab, "'<Tab>' keymap should be set for next occurrence")
      assert.is_true(has_stab, "'<S-Tab>' keymap should be set for previous occurrence")
      assert.is_true(has_a, "'<leader>a' keymap should be set for marking all occurrences")
      assert.is_true(has_x, "'<leader>x' keymap should be set for unmarking all occurrences")
      assert.is_true(has_q, "'q' keymap should be set for deactivating occurrence mode")
      assert.is_true(has_change, "'c' operator should be enabled for change")
      assert.is_true(has_delete, "'d' operator should be enabled for delete")
      assert.is_true(has_yank, "'y' operator should be enabled for yank")
      assert.is_false(has_rot13, "'g?' operator should be disabled for ROT13")
      assert.is_false(has_swapcase, "'g~' operator should be disabled for swap case")

      feedkeys("<Tab>")
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.same({ 3, 0 }, cursor, "Cursor should move to next occurrence on line 3")

      feedkeys("<Tab>")
      cursor = vim.api.nvim_win_get_cursor(0)
      assert.same({ 1, 0 }, cursor, "Cursor should move back to first occurrence on line 1")

      feedkeys("<S-Tab>")
      cursor = vim.api.nvim_win_get_cursor(0)
      assert.same({ 3, 0 }, cursor, "Cursor should move back to occurrence on line 3")

      feedkeys("<S-Tab>")
      cursor = vim.api.nvim_win_get_cursor(0)
      assert.same({ 1, 0 }, cursor, "Cursor should move back to occurrence on line 1")

      feedkeys("<leader>x")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "All marks should be cleared")

      feedkeys("<leader>a")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Two occurrences of 'This' should be marked again")

      feedkeys("q")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(0, #marks, "All marks should be cleared on deactivate")

      mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      has_tab = false
      has_stab = false
      has_a = false
      has_x = false
      has_q = false
      has_change = false
      has_delete = false
      has_yank = false
      has_rot13 = false
      has_swapcase = false
      for _, map in ipairs(mappings) do
        if map.lhs == "<Tab>" and map.rhs == "<Plug>(OccurrenceNext)" then
          has_tab = true
        end
        if map.lhs == "<S-Tab>" and map.rhs == "<Plug>(OccurrencePrevious)" then
          has_stab = true
        end
        if map.lhs == "\\a" then
          has_a = true
        end
        if map.lhs == "\\x" then
          has_x = true
        end
        if map.lhs == "q" and map.rhs == "<Plug>(OccurrenceDeactivate)" then
          has_q = true
        end
        if map.lhs == "c" then
          has_change = true
        end
        if map.lhs == "d" then
          has_delete = true
        end
        if map.lhs == "y" then
          has_yank = true
        end
        if map.lhs == "g?" then
          has_rot13 = true
        end
        if map.lhs == "g~" then
          has_swapcase = true
        end
      end
      assert.is_false(has_tab, "'<Tab>' keymap should be removed for next occurrence")
      assert.is_false(has_stab, "'<S-Tab>' keymap should be removed for previous occurrence")
      assert.is_false(has_a, "'<leader>a' keymap should be removed for marking all occurrences")
      assert.is_false(has_x, "'<leader>x' keymap should be removed for unmarking all occurrences")
      assert.is_false(has_q, "'q' keymap should be removed for deactivating occurrence mode")
      assert.is_false(has_change, "'c' operator should be removed for change")
      assert.is_false(has_delete, "'d' operator should be removed for delete")
      assert.is_false(has_yank, "'y' operator should be enabled for yank")
      assert.is_false(has_rot13, "'g?' operator should be disabled for ROT13")
      assert.is_false(has_swapcase, "'g~' operator should be disabled for swap case")
    end)

    it("describes custom line-based dd operator accurately", function()
      bufnr = util.buffer({
        "line foo one foo",
        "line foo two foo",
        "line foo three foo",
      })

      plugin.setup({
        keymaps = {
          -- dd - Delete marked occurrences on current line
          ["dd"] = {
            mode = "n",
            desc = "Delete marked occurrences on line",
            callback = function(occ)
              local range = require("occurrence.Range").of_line()
              return occ:apply_operator("delete", { motion = range, motion_type = "line" })
            end,
          },
        },
      })

      -- Place cursor on second "foo"
      vim.api.nvim_win_set_cursor(0, { 1, 13 })

      feedkeys("godd")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(4, #marks, "4 'foo' occurrences should be marked")

      assert.same({
        "line  one ",
        "line foo two foo",
        "line foo three foo",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'foo' occurrences on line 1 should be deleted")

      -- Place cursor on second line "foo"
      vim.api.nvim_win_set_cursor(0, { 2, 5 })
      feedkeys("dd")

      assert.same({
        "line  one ",
        "line  two ",
        "line foo three foo",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'foo' occurrences on line 2 should be deleted")

      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")

      -- Place cursor on third line "foo"
      vim.api.nvim_win_set_cursor(0, { 3, 5 })
      feedkeys(".")

      assert.same({
        "line  one ",
        "line  two ",
        "line  three ",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'foo' occurrences on line 3 should be deleted by repeat")
    end)

    it("describes custom line-based D operator accurately", function()
      bufnr = util.buffer({
        "delete foo here foo",
        "delete foo there foo",
        "delete foo everywhere foo",
      })

      plugin.setup({
        keymaps = {
          -- D - Delete marked occurrences from cursor to end of line
          ["D"] = {
            mode = "n",
            desc = "Delete marked occurrences from cursor to end of line",
            callback = function(occ)
              occ:apply_operator("delete", { motion = "$" })
            end,
          },
        },
      })

      -- Place cursor on second "foo"
      vim.api.nvim_win_set_cursor(0, { 1, 16 })

      feedkeys("goD")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(5, #marks, "5 remaining 'foo' occurrences should be marked")

      assert.same(
        {
          "delete foo here ",
          "delete foo there foo",
          "delete foo everywhere foo",
        },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        "'foo' occurrence from cursor to EOL on line 1 should be deleted"
      )

      -- Place cursor second line first "foo"
      vim.api.nvim_win_set_cursor(0, { 2, 7 })
      feedkeys("D")

      assert.same(
        {
          "delete foo here ",
          "delete  there ",
          "delete foo everywhere foo",
        },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        "'foo' occurrence from cursor to EOL on line 2 should be deleted"
      )

      feedkeys("<Esc>")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")

      -- Place cursor on third line second "foo"
      vim.api.nvim_win_set_cursor(0, { 3, 22 })
      feedkeys(".")

      assert.same(
        {
          "delete foo here ",
          "delete  there ",
          "delete foo everywhere ",
        },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        "'foo' occurrence from cursor to EOL on line 3 should be deleted by repeat"
      )
    end)

    it("describes custom line-based cc operator accurately", function()
      bufnr = util.buffer({
        "change foo this foo",
        "change foo that foo",
        "change foo other foo",
      })

      plugin.setup({
        on_activate = function(map)
          -- cc - Change marked occurrences on current line
          map("n", "cc", function()
            local occ = require("occurrence.Occurrence").get()
            local range = require("occurrence.Range").of_line()
            occ:apply_operator("change", { motion = range, motion_type = "line" })
          end, { desc = "Change marked occurrences on line" })
        end,
      })

      -- Mock vim.fn.input to return "test"
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("test")

      -- Place cursor on second "foo"
      vim.api.nvim_win_set_cursor(0, { 1, 16 })

      feedkeys("gocc")

      assert.same({
        "change test this test",
        "change foo that foo",
        "change foo other foo",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'foo' occurrences on line 1 should be changed")

      -- Place cursor on second line "foo"
      vim.api.nvim_win_set_cursor(0, { 2, 7 })
      feedkeys("cc")

      assert.same({
        "change test this test",
        "change test that test",
        "change foo other foo",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'foo' occurrences on line 2 should be changed")

      feedkeys("<Esc>")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")

      -- Place cursor on third line second "foo"
      vim.api.nvim_win_set_cursor(0, { 3, 16 })
      feedkeys(".")

      assert.same({
        "change test this test",
        "change test that test",
        "change test other test",
      }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "'foo' occurrences on line 3 should be changed by repeat")

      input_stub:revert()
    end)

    it("describes custom line-based C operator accurately", function()
      bufnr = util.buffer({
        "change foo here foo",
        "change foo there foo",
        "change foo everywhere foo",
      })

      plugin.setup({
        on_activate = function(map)
          -- C - Change marked occurrences from cursor to end of line
          map("n", "C", function()
            local occ = require("occurrence.Occurrence").get()
            occ:apply_operator("change", { motion = "$" })
          end, { desc = "Change marked occurrences from cursor to end of line" })
        end,
      })

      -- Mock vim.fn.input to return "test"
      local input_stub = stub(vim.fn, "input")
      input_stub.returns("test")
      -- Place cursor on second "foo"
      vim.api.nvim_win_set_cursor(0, { 1, 16 })

      feedkeys("goC")

      assert.same(
        {
          "change foo here test",
          "change foo there foo",
          "change foo everywhere foo",
        },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        "'foo' occurrence from cursor to EOL on line 1 should be changed"
      )

      -- Place cursor second line first "foo"
      vim.api.nvim_win_set_cursor(0, { 2, 7 })
      feedkeys("C")

      assert.same(
        {
          "change foo here test",
          "change test there test",
          "change foo everywhere foo",
        },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        "'foo' occurrences from cursor to EOL on line 2 should be changed"
      )

      feedkeys("<Esc>")
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")

      -- Place cursor on third line second "foo"
      vim.api.nvim_win_set_cursor(0, { 3, 22 })
      feedkeys(".")

      assert.same(
        {
          "change foo here test",
          "change test there test",
          "change foo everywhere test",
        },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        "'foo' occurrence from cursor to EOL on line 3 should be changed by repeat"
      )

      input_stub:revert()
    end)
  end)

  describe("Example: Selective Editing", function()
    it("allows marking occurrences, navigating, unmarking some, then changing others", function()
      bufnr = util.buffer({
        "The quick brown fox jumps over the lazy dog.",
        "The fox is quick and the dog is lazy.",
        "Another fox and dog appear here.",
      })

      plugin.setup()

      -- Place cursor on first "fox"
      vim.api.nvim_win_set_cursor(0, { 1, 16 }) -- "fox" on line 1

      -- go - Mark all occurrences of word under cursor
      feedkeys("go")

      -- Verify all 3 "fox" occurrences are marked
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'fox' occurrences should be marked")

      -- n - Navigate to next occurrence (should be on line 2)
      feedkeys("n")
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, cursor[1], "Cursor should move to second 'fox' on line 2")
      assert.equals(4, cursor[2], "Cursor should be at 'fox' position")

      -- gx - Unmark this one (skip it)
      feedkeys("gx")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(2, #marks, "Should have 2 marks after unmarking one")

      -- n - Navigate to next (should be on line 3)
      feedkeys("n")
      cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1], "Cursor should move to third 'fox' on line 3")

      local input_stub = stub(vim.fn, "input")
      input_stub.returns("wolf")

      feedkeys("cip") -- 'c'hange 'i'n 'p'aragraph

      -- Verify changes applied only to marked occurrences (lines 1 and 3)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "The quick brown wolf jumps over the lazy dog.",
        "The fox is quick and the dog is lazy.",
        "Another wolf and dog appear here.",
      }, lines, "'fox' occurrences on lines 1 and 3 should be changed to 'wolf'")

      -- <Esc> - Clear marks
      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")

      input_stub:revert()
    end)
  end)

  describe("Example: Working with Search Patterns", function()
    it("marks occurrences from last search pattern", function()
      bufnr = util.buffer({
        "The quick brown fox jumps over the lazy dog.",
        "The fox is quick and the dog is lazy.",
        "Another fox and dog appear here.",
      })

      plugin.setup()

      -- Search for 3-letter words
      vim.fn.setreg("/", "\\<...\\>")
      vim.v.hlsearch = 1

      -- go - Mark all occurrences matching the search pattern
      feedkeys("go")

      -- Verify all 3-letter words are marked
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      -- foo, bar, baz, qux, foo, bar, baz, qux, foo = 9 occurrences
      assert.equals(12, #marks, "All 3-letter words should be marked")

      feedkeys("gggUG") -- Uppercase all marked occurrences

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "THE quick brown FOX jumps over THE lazy DOG.",
        "THE FOX is quick AND THE DOG is lazy.",
        "Another FOX AND DOG appear here.",
      }, lines, "All marked occurrences should be uppercased")

      -- Clean up
      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")
    end)
  end)

  describe("Example: Working with Multiple Patterns", function()
    it("marks different words and edits them together", function()
      bufnr = util.buffer({
        "foo is here and bar is there",
        "foo and bar together",
        "only foo here",
        "only bar there",
      })

      plugin.setup()

      -- Place cursor on first "foo" on line 1
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- mark "foo" occurrences and enter occurrence mode
      feedkeys("go")

      -- Verify "foo" marks
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'foo' occurrences should be marked")

      -- Move to "bar" and mark it too
      vim.api.nvim_win_set_cursor(0, { 1, 18 }) -- Move to middle of "bar"
      feedkeys("ga") -- This adds all "bar" occurrences as a new pattern

      -- Verify both "foo" and "bar" marks
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(6, #marks, "All 'foo' and 'bar' occurrences should be marked")

      local input_stub = stub(vim.fn, "input")
      input_stub.returns("test")

      feedkeys("cip") -- 'c'hange 'i'n 'p'aragraph

      -- Verify changes applied to all marked occurrences
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "test is here and test is there",
        "test and test together",
        "only test here",
        "only test there",
      }, lines, "All 'foo' and 'bar' occurrences should be changed to 'test'")

      -- Clean up
      feedkeys("<Esc>")
      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared")

      input_stub:revert()
    end)
  end)

  describe("Example: Yanking and Putting occurrences", function()
    it("yanks marked occurrences and pastes at different locations", function()
      bufnr = util.buffer({
        "SOURCE SOURCE SOURCE",
        "dest dest dest",
      })

      plugin.setup()

      -- Mark "SOURCE" occurrences
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      feedkeys("go")

      -- Verify marks
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'SOURCE' occurrences should be marked")

      -- y - Yank all marked occurrences
      feedkeys("y$")

      -- Verify yank register has all sources
      local register = vim.fn.getreg('"')
      assert.equals("SOURCE\nSOURCE\nSOURCE", register, "Register should contain all yanked occurrences")

      -- Exit occurrence mode
      feedkeys("<Esc>")

      -- Move to "dest" and mark those occurrences
      feedkeys("j^")
      feedkeys("go")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All 'dest' occurrences should be marked")

      -- p - Put yanked text at all marked locations (replicates the same content)
      feedkeys("p$")

      -- Verify paste replaced all destinations with the full yanked content
      -- Each "dest" is replaced with "SOURCE\nSOURCE\nSOURCE" (multi-line)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "SOURCE SOURCE SOURCE",
        "SOURCE",
        "SOURCE",
        "SOURCE SOURCE",
        "SOURCE",
        "SOURCE SOURCE",
        "SOURCE",
        "SOURCE",
      }, lines, "Destinations should be replaced with yanked content")
    end)
  end)

  describe("Example: Distribute Pattern (Copy-Paste-Distribute)", function()
    it("distributes yanked values across marked occurrences", function()
      bufnr = util.buffer({
        "alpha foo beta bar gamma bat",
        "foo dest bar dest bat dest",
      })

      plugin.setup()

      -- Mark source occurrences using a pattern that matches all three
      vim.fn.setreg("/", "\\(alpha\\|beta\\|gamma\\)")
      vim.v.hlsearch = 1

      feedkeys("go")

      -- Verify marks for sources
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(3, #marks, "All alpha|beta|gamma occurrences should be marked")

      -- Yank all marked sources on the line
      feedkeys("Vy")

      -- Verify yank register has all sources
      local register = vim.fn.getreg('"')
      assert.equals("alpha\nbeta\ngamma", register, "Register should contain all sources separated by newlines")

      -- Exit occurrence mode
      feedkeys("<Esc>")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.same({}, marks, "All marks should be cleared after exiting occurrence mode")

      vim.fn.setreg("/", "\\(foo\\|bar\\|bat\\)")
      vim.v.hlsearch = 1
      feedkeys("go")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, MARK_NS, 0, -1, {})
      assert.equals(6, #marks, "All foo|bar|bat occurrences should be marked")

      -- gp - Distribute yanked lines across marked locations on the line
      feedkeys("jVgp")

      -- Verify distribute worked: each destination gets a different source
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.same({
        "alpha foo beta bar gamma bat",
        "alpha dest beta dest gamma dest",
      }, lines, "Destinations should be replaced with distributed sources")
    end)
  end)
end)
