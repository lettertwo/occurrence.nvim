-- A 0-indexed line and column pair representing a location in a buffer,
-- e.g., the cursor position, or a mark location, or the start or end of a range.
---@see occurrency.Range
---@class Location
---@operator call: Location
---@operator add(integer): Location
---@field line integer A 0-indexed line number.
---@field col integer A 0-indexed column number.
local Location = {}

local function readonly()
  error("Location is read-only")
end

---@param location Location
local function tostring(location)
  return string.format("Location(%d, %d)", location.line, location.col)
end

-- Creates a new `Location` from the given line and column numbers.
-- If either argument is invalid, returns `nil`.
-- @param line A 0-indexed line number.
-- @param col A 0-indexed column number.
---@return Location
function Location:new(line, col)
  assert(type(line) == "number", "line must be a number")
  assert(type(col) == "number", "col must be a number")
  assert(line >= 0, "line must be >= 0")
  assert(col >= 0, "col must be >= 0")

  local location = { line, col }
  location.line = line
  location.col = col

  return setmetatable(location, {
    __index = self,
    __call = self.new,
    __newindex = readonly,
    __tostring = tostring,
    __add = self.add,
    __lt = self.lt,
    __le = self.le,
    __eq = self.eq,
    __gt = self.gt,
    __ge = self.ge,
  })
end

-- Serializes the `Location` to a string.
-- For a pretty-printed representation, use `tostring(Location)`.
---@return string
function Location:serialize()
  return table.concat(self, ":")
end

-- Create a new `Location` from a `Location:serialize()` string.
---@param str string
---@return Location
function Location:deserialize(str)
  local line, col = str:match("^(%d+):(%d+)$")
  return self:new(tonumber(line), tonumber(col))
end

-- Creates a new `Location` from the given 'mark-like' position.
-- A 'mark-like' position has 1-based lines, and 0-based columns.
-- If the position is invalid, returns `nil`.
---@param pos integer[] A (1,0)-indexed position tuple.
function Location:from_markpos(pos)
  local line = pos and pos[1]
  local col = pos and pos[2]
  if line < 1 or col < 0 then
    return nil
  end
  return self:new(line - 1, col)
end

-- Returns a 'mark-like' position for the given `Location`.
-- A 'mark-like' position has 1-based lines, and 0-based columns.
---@return integer[] A (1,0)-indexed position tuple.
function Location:to_markpos()
  return { self.line + 1, self.col }
end

-- Get the location of the cursor.
function Location:of_cursor()
  return self:from_markpos(vim.api.nvim_win_get_cursor(0))
end

-- Get the location of a mark.
-- Note: Mark names are not prefixed with a quote.
---@param mark string
function Location:of_mark(mark)
  return self:from_markpos(vim.api.nvim_buf_get_mark(0, mark))
end

-- Get a new `Location` from a position tuple.
-- This could be a 2-tuple of `{line, col}`
-- or a 3+-tuple of, e.g., `{buffer, line, col, ...}`.
--
-- The tuple positions are expected to 'search-like',
-- as returned by functions like `vim.fn.getpos()` or `vim.fn.searchpos()`.
---@param pos integer[]
function Location:from_pos(pos)
  if not pos or #pos < 2 then
    return nil
  end
  local line = pos[1]
  local col = pos[2]
  if #pos > 2 then
    line = pos[2]
    col = pos[3]
  end
  if line < 1 or col < 1 then
    return nil
  end
  return self:new(line - 1, col - 1)
end

-- Creates a new `Location` from the given 'search-like' position.
-- A 'search-like' position has 1-based lines, and 1-based columns.
--
-- If the position is invalid, returns `nil`.
---@param pos integer[] A 1-indexed position tuple.
function Location:from_searchpos(pos)
  return self:from_pos(pos)
end

-- Returns a 'search-like' position for the given `Location`.
-- A 'search-like' position has 1-based lines, and 1-based columns.
---@return integer[] A 1-indexed position tuple.
function Location:to_searchpos()
  return { self.line + 1, self.col + 1 }
end

--- Returns the distance between this `Location` and another `Location`.
---@param other Location
function Location:distance(other)
  local a = math.abs(self.line - other.line)
  local b = math.abs(self.col - other.col)
  return math.sqrt(a * a + b * b)
end

-- Add an offset to a `Location` to get a new `Location`.
-- A single integer argument is interpreted as a column offset.
-- Two integer arguments are interpreted as line and column offsets.
---@param col_or_line integer
---@param col? integer
---@overload fun(self: Location, col: integer): Location
---@overload fun(self: Location, line: integer, col: integer): Location
function Location:add(col_or_line, col)
  if col ~= nil then
    return self:new(self.line + col_or_line, self.col + col)
  elseif type(col_or_line) == "number" then
    return self:new(self.line, self.col + col_or_line)
  else
    return self:new(self.line + col_or_line.line, self.col + col_or_line.col)
  end
end

---@param other Location
function Location:lt(other)
  return self.line < other.line or self.line == other.line and self.col < other.col
end

---@param other Location
function Location:le(other)
  return self:lt(other) or self:eq(other)
end

---@param other Location
function Location:eq(other)
  return self.line == other.line and self.col == other.col
end

---@param other Location
function Location:gt(other)
  return self.line > other.line or self.line == other.line and self.col > other.col
end

---@param other Location
function Location:ge(other)
  return self:gt(other) or self:eq(other)
end

return Location
