local Location = require("occurrence.Location")

---@module 'occurrence.Cursor'
local cursor = {}

---@class occurrence.Cursor
---@field location occurrence.Location
local Cursor = {}

-- Restore the cursor to the previously saved position.
function Cursor:restore()
  cursor.move(self.location)
end

-- Update the saved position to the current cursor position.
function Cursor:save()
  self.location = Location.of_cursor() or self.location
end

-- Move the cursor to a new position.
---@param location occurrence.Location
function Cursor:move(location)
  cursor.move(location)
end

-- Save the current position for later restoration.
---@return occurrence.Cursor
function cursor.save()
  local location = Location.of_cursor()
  assert(location, "Cursor is not in current window")
  return setmetatable({ location = location }, { __index = Cursor })
end

--- Move the cursor to the given `Location`.
---@param location occurrence.Location
function cursor.move(location)
  -- TODO: figure out if we can use nvim api instead?
  -- Currently not doing so because it appears to always scroll the window.
  -- vim.api.nvim_win_set_cursor(0, location:to_markpos())
  vim.fn.setpos(".", vim.iter({ 0, location:to_pos(), 0 }):flatten():totable())
end

return cursor
