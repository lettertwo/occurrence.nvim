local Location = require("occurrence.Location")
local log = require("occurrence.log")

-- A 0-indexed `Location` pair representing a range of a buffer,
-- e.g., a search match, a selection, or the boundaries of a motion.
--
-- Note that the range is end-exclusive, meaning that the `stop` location
-- is not included in the range.
---@see Location
--
---@class Range
---@overload fun(start: Location, stop: Location): Range
---@field start Location
---@field stop Location
local Range = {}

local function readonly()
  error("Range is read-only")
end

---@param range Range
local function tostring(range)
  return string.format("Range(start: %s, stop: %s)", range.start, range.stop)
end

-- Creates a new `Range` from the given `start` and `stop` locations.
-- The range will be end-exclusive, meaning that the `stop` location
-- will not be included in the range.
---@param start Location
---@param stop Location
---@return Range
function Range:new(start, stop)
  assert(type(start) == "table", "start must be a Location")
  assert(type(stop) == "table", "stop must be a Location")
  assert(start <= stop, "start must be less than or equal to start")

  local range = vim.tbl_flatten({ start, stop })
  range.start = start
  range.stop = stop

  return setmetatable(range, {
    __index = self,
    __call = self.new,
    __newindex = readonly,
    __tostring = tostring,
    __eq = self.eq,
  })
end

-- Serializes the `Range` to a string.
-- For a pretty-printed representation, use `tostring(Range)`.
---@return string
function Range:serialize()
  return table.concat({ self.start:serialize(), self.stop:serialize() }, "::")
end

-- Create a new `Range` from a `Range:serialize()` string.
---@param str string
---@return Range
function Range:deserialize(str)
  local start, stop = str:match("^(.+)%:%:(.+)$")
  return self:new(Location:deserialize(start), Location:deserialize(stop))
end

-- Get the range of the active visual selection.
-- Returns `nil` if there is no active selection, or the selection is blockwise.
function Range:of_selection()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" then
    -- Turns out that finding the active selection range is not straightfoward.
    -- The `'<,'>` mark pair refers to the _previous_ selection (after leaving visual mode),
    -- so is of no help for finding the current selection.
    -- Two possible solutions:
    -- 1. forceably leave visual mode, grab the range using the `'<,'>` mark pair,
    --    then re-enter visual mode using `gv`.
    -- 2. Use `vim.fn.getpos('v') to get the start of the current selection range,
    --    then use the cursor position as the end of the range.
    -- The second option is what we do here, but it does feel fragile.
    local vstart = vim.fn.getpos("v")
    if vstart ~= nil then
      local start = Location:from_pos(vstart)
      local stop = Location:of_cursor()
      if start and stop then
        if stop < start then
          start, stop = stop, start
        end
        if mode == "V" then
          start = Location:new(start.line, 0)
          stop = Location:of_line_end(stop.line)
        end
        return self:new(start, stop)
      end
    end
  end
  error("could not determine selection range")
end

-- Get the range of the most recent motion.
-- See `:help g@` for details on `motion_type`.
---@param motion_type? 'char' | 'line' | 'block' (default: 'char')
function Range:of_motion(motion_type)
  if motion_type == "block" then
    error("blockwise motions are not yet supported")
  end
  local start = Location:of_mark("[")
  local stop = Location:of_mark("]")
  if start and stop then
    if stop < start then
      start, stop = stop, start
    end
    if motion_type == "line" then
      start = Location:new(start.line, 0)
      stop = Location:of_line_end(stop.line)
    end
    return self:new(start, stop)
  end
  error("could not determine motion range")
end

-- Get the range of a line.
-- If no `line` is given, uses the current cursor line.
---@param line integer? A 0-indexed line number.
function Range:of_line(line)
  local start = Location:of_line_start(line)
  local stop = Location:of_line_end(line)
  return self:new(start, stop)
end

-- Transpose this range to a new starting location.
---@param start Location
---@return Range
function Range:move(start)
  local line_diff = start.line - self.start.line
  local col_diff = start.col - self.start.col
  return self:new(start, self.stop:add(line_diff, col_diff))
end

-- Compare the given `Location` or `Range` to this `Range`.
--
-- A `Location` is considered to be contained if it is greater than
-- or equal to the start location, and less than the stop location.
--
-- A `Range` is considered to be contained if its start location
-- is greater than or equal to the start location, and its stop location
-- is less than or equal to the stop location.
---@param other Range | Location
---@return boolean
function Range:contains(other)
  if other.start and other.stop then
    return self.start <= other.start and other.stop <= self.stop
  else
    return self.start <= other and other < self.stop
  end
end

-- Compare the given `Range` to this `Range`.
-- Ranges are considered equal if their start and stop locations are equal.
---@param other Range
function Range:eq(other)
  return self.start == other.start and self.stop == other.stop
end

return Range
