local Location = require("occurrency.Location")
local log = require("occurrency.log")

-- A 0-indexed `Location` pair representing a range of a buffer,
-- e.g., a search match, a selection, or the boundaries of a motion.
--
-- Note that the range is end-exclusive, meaning that the `stop` location
-- is not included in the range.
---@see Location
---@class Range
---@operator call: Location
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

-- Get the range of the most recent selection.
function Range:of_selection()
  local start = Location:of_mark("'<")
  local stop = Location:of_mark("'>")
  if start and stop then
    return self:new(start, stop)
  end
end

-- Get the range of the most recent motion.
function Range:of_motion()
  local start = Location:of_mark("'[")
  local stop = Location:of_mark("']")
  if start and stop then
    return self:new(start, stop)
  end
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
