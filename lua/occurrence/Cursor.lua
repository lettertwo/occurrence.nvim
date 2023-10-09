local Location = require("occurrence.Location")
local log = require("occurrence.log")

---@class Cursor
local Cursor = {}

---@class CursorMemory: Cursor
---@field location Location
local CursorMemory = setmetatable({}, { __index = Cursor })

function CursorMemory:new(location)
  return setmetatable({ location = location }, { __index = self })
end

-- Restore the cursor to the previously saved position.
function CursorMemory:restore()
  self:move(self.location)
end

-- Save the current position for later restoration.
function Cursor:save()
  local location = Location:of_cursor()
  assert(location, "Cursor is not in current window")
  return CursorMemory:new(location)
end

--- Move the cursor to the given `Location`.
---@param location Location
function Cursor:move(location)
  -- TODO: figure out if we can use nvim api instead?
  -- Currently not doing so because it appears to always scroll the window.
  -- vim.api.nvim_win_set_cursor(0, location:to_markpos())
  vim.fn.setpos(".", vim.tbl_flatten({ 0, location:to_searchpos(), 0 }))
end

return Cursor
