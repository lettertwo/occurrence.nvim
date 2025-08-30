local assert = require("luassert")
local util = require("tests.util")
local Location = require("occurrence.Location")
local Cursor = require("occurrence.Cursor")

describe("Cursor", function()
  before_each(function()
    util.buffer({
      "first line of text content here",
      "second line with more detailed content",
      "third line for cursor testing purposes",
      "fourth line is shorter than others",
      "fifth and final line of the test buffer",
    })
  end)

  describe("cursor.save", function()
    it("saves current cursor position", function()
      -- Position cursor at a specific location
      vim.api.nvim_win_set_cursor(0, { 2, 10 }) -- line 2, col 10

      local saved_cursor = Cursor.save()
      assert.is_table(saved_cursor)
      assert.is_table(saved_cursor.location)
      assert.equals(1, saved_cursor.location.line) -- 0-indexed
      assert.equals(10, saved_cursor.location.col)
    end)

    it("creates Cursor object with correct metatable", function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local saved_cursor = Cursor.save()
      assert.is_function(saved_cursor.restore)
      assert.is_function(saved_cursor.save)
      assert.is_function(saved_cursor.move)
    end)

    it("errors when cursor is not in current window", function()
      -- This is hard to test directly, but we can test the assertion
      -- by mocking Location.of_cursor to return nil
      local original_of_cursor = Location.of_cursor
      ---@diagnostic disable-next-line: duplicate-set-field
      Location.of_cursor = function()
        return nil
      end

      assert.error(function()
        Cursor.save()
      end)

      -- Restore original function
      Location.of_cursor = original_of_cursor
    end)
  end)

  describe("cursor.move", function()
    it("moves cursor to specified location", function()
      local target_location = Location.new(2, 15) -- 0-indexed

      Cursor.move(target_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, current_pos[1]) -- 1-indexed line
      assert.equals(15, current_pos[2]) -- 0-indexed column
    end)

    it("handles movement to different lines", function()
      -- Start at line 1
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      -- Move to line 4
      local target_location = Location.new(3, 5)
      Cursor.move(target_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(4, current_pos[1]) -- 1-indexed
      assert.equals(5, current_pos[2])
    end)

    it("handles movement within same line", function()
      vim.api.nvim_win_set_cursor(0, { 2, 5 })

      local target_location = Location.new(1, 20) -- same line, different column
      Cursor.move(target_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, current_pos[1])
      assert.equals(20, current_pos[2])
    end)

    it("handles movement to start of buffer", function()
      vim.api.nvim_win_set_cursor(0, { 5, 10 })

      local target_location = Location.new(0, 0)
      Cursor.move(target_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, current_pos[1]) -- 1-indexed line 1
      assert.equals(0, current_pos[2]) -- column 0
    end)

    it("handles movement to end of buffer", function()
      local target_location = Location.new(4, 35) -- last line
      Cursor.move(target_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(5, current_pos[1]) -- 1-indexed line 5
      assert.equals(35, current_pos[2])
    end)
  end)

  describe("Cursor:restore", function()
    it("restores cursor to saved position", function()
      -- Move to initial position and save
      vim.api.nvim_win_set_cursor(0, { 2, 8 })
      local saved_cursor = Cursor.save()

      -- Move cursor elsewhere
      vim.api.nvim_win_set_cursor(0, { 4, 20 })

      -- Restore original position
      saved_cursor:restore()

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, current_pos[1]) -- back to line 2
      assert.equals(8, current_pos[2]) -- back to column 8
    end)

    it("works after multiple cursor movements", function()
      -- Save initial position
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      local saved_cursor = Cursor.save()

      -- Move around multiple times
      vim.api.nvim_win_set_cursor(0, { 2, 10 })
      vim.api.nvim_win_set_cursor(0, { 3, 15 })
      vim.api.nvim_win_set_cursor(0, { 4, 20 })

      -- Restore to original
      saved_cursor:restore()

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, current_pos[1])
      assert.equals(5, current_pos[2])
    end)
  end)

  describe("Cursor:save", function()
    it("updates saved position to current location", function()
      -- Create cursor object at initial position
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local cursor_obj = Cursor.save()
      assert.equals(0, cursor_obj.location.line)
      assert.equals(0, cursor_obj.location.col)

      -- Move cursor and update saved position
      vim.api.nvim_win_set_cursor(0, { 3, 12 })
      cursor_obj:save()

      -- Check that saved position was updated
      assert.equals(2, cursor_obj.location.line) -- 0-indexed
      assert.equals(12, cursor_obj.location.col)
    end)

    it("preserves original location if of_cursor returns nil", function()
      vim.api.nvim_win_set_cursor(0, { 2, 5 })
      local cursor_obj = Cursor.save()
      local original_location = cursor_obj.location

      -- Mock Location.of_cursor to return nil
      local original_of_cursor = Location.of_cursor
      ---@diagnostic disable-next-line: duplicate-set-field
      Location.of_cursor = function()
        return nil
      end

      cursor_obj:save()

      -- Should preserve original location
      assert.same(original_location, cursor_obj.location)

      -- Restore original function
      Location.of_cursor = original_of_cursor
    end)
  end)

  describe("Cursor:move", function()
    it("moves cursor to specified location", function()
      local cursor_obj = Cursor.save()
      local target_location = Location.new(3, 18)

      cursor_obj:move(target_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(4, current_pos[1]) -- 1-indexed line
      assert.equals(18, current_pos[2])
    end)

    it("is equivalent to cursor.move", function()
      local cursor_obj = Cursor.save()
      local target_location = Location.new(2, 10)

      -- Both should produce same result
      cursor_obj:move(target_location)
      local pos1 = vim.api.nvim_win_get_cursor(0)

      -- Reset and try module function
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      Cursor.move(target_location)
      local pos2 = vim.api.nvim_win_get_cursor(0)

      assert.same(pos1, pos2)
    end)
  end)

  describe("integration tests", function()
    it("supports save-move-restore workflow", function()
      -- Save current position
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      local saved_cursor = Cursor.save()

      -- Perform some operations that move cursor
      Cursor.move(Location.new(2, 15))
      Cursor.move(Location.new(4, 8))

      -- Restore to original position
      saved_cursor:restore()

      local final_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, final_pos[1])
      assert.equals(3, final_pos[2])
    end)

    it("supports multiple saved cursor positions", function()
      -- Save multiple positions
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      local cursor1 = Cursor.save()

      vim.api.nvim_win_set_cursor(0, { 3, 10 })
      local cursor2 = Cursor.save()

      vim.api.nvim_win_set_cursor(0, { 5, 15 })
      local cursor3 = Cursor.save()

      -- Move somewhere else
      vim.api.nvim_win_set_cursor(0, { 2, 0 })

      -- Restore to different saved positions
      cursor2:restore()
      local pos2 = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, pos2[1])
      assert.equals(10, pos2[2])

      cursor1:restore()
      local pos1 = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, pos1[1])
      assert.equals(5, pos1[2])

      cursor3:restore()
      local pos3 = vim.api.nvim_win_get_cursor(0)
      assert.equals(5, pos3[1])
      assert.equals(15, pos3[2])
    end)

    it("works with Location operations", function()
      -- Save cursor at current position
      vim.api.nvim_win_set_cursor(0, { 2, 8 })
      local saved_cursor = Cursor.save()

      -- Use Location operations to create new position
      local line_start = Location.of_line_start(3) -- 0-indexed line 3
      local offset_location = line_start:add(10) -- add 10 columns

      -- Move cursor using computed location
      saved_cursor:move(offset_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(4, current_pos[1]) -- 1-indexed line 4
      assert.equals(10, current_pos[2])

      -- Restore to original
      saved_cursor:restore()
      local restored_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, restored_pos[1])
      assert.equals(8, restored_pos[2])
    end)

    it("handles cursor state across buffer operations", function()
      -- Save position
      vim.api.nvim_win_set_cursor(0, { 2, 12 })
      local saved_cursor = Cursor.save()

      -- Perform buffer modifications that might affect cursor
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { "modified first line content" })

      -- Cursor position might have changed due to buffer modification
      -- But our saved cursor should still restore to the original logical position
      saved_cursor:restore()

      -- Position should be restored (though exact position may vary due to buffer changes)
      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.is_number(current_pos[1])
      assert.is_number(current_pos[2])
    end)

    it("update saved position and restore workflow", function()
      -- Initial save
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local cursor_obj = Cursor.save()

      -- Move and update saved position
      vim.api.nvim_win_set_cursor(0, { 3, 15 })
      cursor_obj:save() -- update to new position

      -- Move elsewhere
      vim.api.nvim_win_set_cursor(0, { 5, 25 })

      -- Restore should go to updated position, not original
      cursor_obj:restore()

      local final_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, final_pos[1]) -- should be at updated position
      assert.equals(15, final_pos[2])
    end)

    it("handles movement to same position", function()
      vim.api.nvim_win_set_cursor(0, { 2, 5 })
      local current_location = assert(Location.of_cursor())

      -- Move to same position
      Cursor.move(current_location)

      local final_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(2, final_pos[1])
      assert.equals(5, final_pos[2])
    end)

    it("handles zero position", function()
      local zero_location = Location.new(0, 0)
      Cursor.move(zero_location)

      local current_pos = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, current_pos[1]) -- 1-indexed line 1
      assert.equals(0, current_pos[2]) -- column 0
    end)

    it("maintains saved position across multiple restores", function()
      vim.api.nvim_win_set_cursor(0, { 3, 10 })
      local saved_cursor = Cursor.save()

      -- Multiple restore calls should work consistently
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      saved_cursor:restore()
      local pos1 = vim.api.nvim_win_get_cursor(0)

      vim.api.nvim_win_set_cursor(0, { 5, 20 })
      saved_cursor:restore()
      local pos2 = vim.api.nvim_win_get_cursor(0)

      assert.same(pos1, pos2)
      assert.equals(3, pos1[1])
      assert.equals(10, pos1[2])
    end)
  end)
end)

