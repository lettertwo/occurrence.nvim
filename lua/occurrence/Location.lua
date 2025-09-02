-- A 0-indexed line and column pair representing a location in a buffer,
-- e.g., the cursor position, or a mark location, or the start or end of a range.
---@see occurrence.Range

---@module 'occurrence.Location'
local location = {}

---@class occurrence.Location
---@operator add(integer): occurrence.Location
---@overload fun(line: number, col: number): occurrence.Location
---@field line integer A 0-indexed line number.
---@field col integer A 0-indexed column number.
local Location = {}

local function readonly()
  error("Location is read-only")
end

---@param self occurrence.Location
---@return string
local function tostring(self)
  return string.format("Location(%d, %d)", self.line, self.col)
end

-- Creates a new `Location` from the given line and column numbers.
-- If either argument is invalid, returns `nil`.
-- @param line A 0-indexed line number.
-- @param col A 0-indexed column number.
---@return occurrence.Location
function location.new(line, col)
  assert(type(line) == "number", "line must be a number")
  assert(type(col) == "number", "col must be a number")
  assert(line >= 0, "line must be >= 0")
  assert(col >= 0, "col must be >= 0")

  local self = { line, col }

  return setmetatable(self, {
    __index = function(t, k)
      if k == "line" then
        return line
      elseif k == "col" then
        return col
      else
        return Location[k]
      end
    end,
    __call = location.new,
    __newindex = readonly,
    __tostring = tostring,
    __add = Location.add,
    __lt = Location.lt,
    __le = Location.le,
    __eq = Location.eq,
    __gt = Location.gt,
    __ge = Location.ge,
  })
end

-- Creates a new `Location` from the given 'mark-like' position.
-- A 'mark-like' position has 1-based lines, and 0-based columns.
--
-- The following API functions use "mark-like" indexing:
--
-- - nvim_get_mark()
-- - nvim_buf_get_mark()
-- - nvim_buf_set_mark()
-- - nvim_win_get_cursor()
-- - nvim_win_set_cursor()
--
-- If the position is invalid, returns `nil`.
--
---@param pos integer[] A "mark-like" (1,0)-indexed position tuple.
---@return occurrence.Location?
function location.from_markpos(pos)
  local line = pos and pos[1]
  local col = pos and pos[2]
  if line < 1 or col < 0 then
    return nil
  end
  return location.new(line - 1, col)
end

-- Get a new `Location` from a position tuple.
-- This could be a 2-tuple of `{line, col}`
-- or a 3+-tuple of, e.g., `{buffer, line, col, ...}`.
--
-- The tuple positions are expected to be 'search-like',
-- as returned by functions like:
--
-- - vim.fn.searchpos()
-- - vim.fn.getpos()
-- - vim.fn.setpos()
--
-- If the position is invalid, returns `nil`.
--
---@param pos integer[]
---@return occurrence.Location?
function location.from_pos(pos)
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
  return location.new(line - 1, col - 1)
end

-- Creates a new `Location` from the given 'extmark-like' position.
-- An 'extmark-like' position has 0-based lines, and 0-based columns.
--
-- The following API functions use "extmark-like" indexing:
--
-- - nvim_buf_del_extmark()
-- - nvim_buf_get_extmark_by_id()
-- - nvim_buf_get_extmarks()
-- - nvim_buf_set_extmark()
--
-- If the position is invalid, returns `nil`.
--
---@param pos integer[] An "extmark-like" (0,0)-indexed position tuple.
---@return occurrence.Location?
function location.from_extmarkpos(pos)
  local line = pos and pos[1]
  local col = pos and pos[2]
  if not line or not col or line < 0 or col < 0 then
    return nil
  end
  return location.new(line, col)
end

-- Get the location of the cursor.
---@return occurrence.Location?
function location.of_cursor()
  return location.from_markpos(vim.api.nvim_win_get_cursor(0))
end

-- Get the location of a mark.
-- Note: Mark names are not prefixed with a quote.
---@param mark string
---@return occurrence.Location?
function location.of_mark(mark)
  return location.from_markpos(vim.api.nvim_buf_get_mark(0, mark))
end

-- Get the location of the start of a line.
-- If no `line` is given, uses the current cursor line.
---@param line integer? A 0-indexed line number.
---@return occurrence.Location
function location.of_line_start(line)
  line = line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
  return location.new(line, 0)
end

-- Get the location of the end of a line.
-- If no `line` is given, uses the current cursor line.
---@param line integer? A 0-indexed line number.
---@return occurrence.Location
function location.of_line_end(line)
  line = line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
  local endcol = vim.api.nvim_buf_get_lines(0, line, line + 1, false)[1]:len()
  return location.new(line, endcol)
end

-- Create a new `Location` from a `Location:serialize()` string.
---@param str string
---@return occurrence.Location
function location.deserialize(str)
  local line, col = str:match("^(%d+):(%d+)$")
  return location.new(tonumber(line), tonumber(col))
end

-- Serializes the `Location` to a string.
-- For a pretty-printed representation, use `tostring(Location)`.
---@return string
function Location:serialize()
  return table.concat(self, ":")
end

-- Returns a plain table representation of the given `Location`.
-- The table has two elements: `{ line, col }`.
---@return integer[]
function Location:totable()
  return vim.list_slice(self)
end

-- Returns an 'extmark-like' position for the given `Location`.
-- An 'extmark-like' position has 0-based lines, and 0-based columns.
--
-- The following API functions use "extmark-like" indexing:
--
-- - nvim_buf_del_extmark()
-- - nvim_buf_get_extmark_by_id()
-- - nvim_buf_get_extmarks()
-- - nvim_buf_set_extmark()
--
---@return integer[] An "extmark-like" (0,0)-indexed position tuple.
function Location:to_extmarkpos()
  return { self.line, self.col }
end

-- Returns a 'search-like' position for the given `Location`.
-- A 'search-like' position has 1-based lines, and 1-based columns.
--
-- The following API functions use 'search-like' indexing:
--
-- - vim.fn.searchpos()
-- - vim.fn.setpos()
--
---@return integer[] A 1-indexed position tuple.
function Location:to_pos()
  return { self.line + 1, self.col + 1 }
end

-- Returns a 'mark-like' position for the given `Location`.
-- A 'mark-like' position has 1-based lines, and 0-based columns.
--
-- The following API functions use "mark-like" indexing:
--
-- - nvim_get_mark()
-- - nvim_buf_get_mark()
-- - nvim_buf_set_mark()
-- - nvim_win_get_cursor()
-- - nvim_win_set_cursor()
--
---@return integer[] A "mark-like" (1,0)-indexed position tuple.
function Location:to_markpos()
  return { self.line + 1, self.col }
end

-- Add an offset to a `Location` to get a new `Location`.
--
-- A single integer argument is interpreted as a column offset.
--
-- Two integer arguments are interpreted as line and column offsets.
--
---@param col_or_line integer
---@param col? integer
---@overload fun(self: occurrence.Location, col: integer): occurrence.Location
---@overload fun(self: occurrence.Location, line: integer, col: integer): occurrence.Location
function Location:add(col_or_line, col)
  if col ~= nil then
    return location.new(self.line + col_or_line, self.col + col)
  elseif type(col_or_line) == "number" then
    return location.new(self.line, self.col + col_or_line)
  else
    error("invalid argument")
  end
end

---@param other occurrence.Location
---@return boolean
function Location:lt(other)
  return self.line < other.line or self.line == other.line and self.col < other.col
end

---@param other occurrence.Location
---@return boolean
function Location:le(other)
  return self:lt(other) or self:eq(other)
end

---@param other occurrence.Location
---@return boolean
function Location:eq(other)
  return self.line == other.line and self.col == other.col
end

---@param other occurrence.Location
---@return boolean
function Location:gt(other)
  return self.line > other.line or self.line == other.line and self.col > other.col
end

---@param other occurrence.Location
---@return boolean
function Location:ge(other)
  return self:gt(other) or self:eq(other)
end

return location
