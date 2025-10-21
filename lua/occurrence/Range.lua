local Location = require("occurrence.Location")
local log = require("occurrence.log")

-- A 0-indexed `Location` pair representing a range of a buffer,
-- e.g., a search match, a selection, or the boundaries of a motion.
--
-- Note that the range is end-exclusive, meaning that the `stop` location
-- is not included in the range.
---@see Location

---@module 'occurrence.Range'
local range = {}

---@class occurrence.Range
---@overload fun(start: occurrence.Location, stop: occurrence.Location): occurrence.Range
---@field start occurrence.Location
---@field stop occurrence.Location
local Range = {}

local function readonly()
  error("Range is read-only")
end

---@param self occurrence.Range
---@return string
local function tostring(self)
  return string.format("Range(start: %s, stop: %s)", self.start, self.stop)
end

-- Creates a new `Range` from the given `start` and `stop` locations.
-- The range will be end-exclusive, meaning that the `stop` location
-- will not be included in the range.
---@param start occurrence.Location
---@param stop occurrence.Location
---@return occurrence.Range
function range.new(start, stop)
  assert(type(start) == "table", "start must be a Location")
  assert(type(stop) == "table", "stop must be a Location")
  assert(start <= stop, "start must be less than or equal to start")

  local self = vim.iter({ start:totable(), stop:totable() }):flatten():totable()

  return setmetatable(self, {
    __index = function(t, k)
      if k == "start" then
        return start
      elseif k == "stop" then
        return stop
      else
        return Range[k]
      end
    end,
    __call = range.new,
    __newindex = readonly,
    __tostring = tostring,
    __eq = Range.eq,
  })
end

-- Get the range of the active visual selection.
-- Returns `nil` if there is no active selection, or the selection is blockwise.
---@return occurrence.Range?
function range.of_selection()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "\22" then -- CTRL-V (blockwise visual mode)
    error("selection is blockwise, which is not yet supported")
  end
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
      local start = Location.from_pos(vstart)
      -- We add 1 because Range is end-exclusive,
      -- and we want the cursor position to be included in the range.
      local stop = Location.of_cursor() + 1
      if start and stop then
        if stop < start then
          start, stop = stop, start
        end
        if mode == "V" then
          start = Location.new(start.line, 0)
          -- We add 1 because Range is end-exclusive,
          -- and we want the entire line to be included in the range.
          stop = Location.of_line_end(stop.line) + 1
        end
        return range.new(start, stop)
      end
    end
  end
  return nil
end

-- Get the range of the most recent motion.
-- See `:help g@` for details on `motion_type`.
-- Returns `nil` if there is no recent motion.
---@param motion_type? 'char' | 'line' | 'block' (default: 'char')
---@return occurrence.Range?
function range.of_motion(motion_type)
  if motion_type == "block" then
    error("blockwise motions are not yet supported")
  end
  local start = Location.of_mark("[")
  local stop = Location.of_mark("]")
  if start and stop then
    if stop < start then
      start, stop = stop, start
    end
    if motion_type == nil or motion_type == "char" then
      -- We add 1 because Range is end-exclusive,
      -- and we want the entire motion to be included in the range.
      stop = stop + 1
    elseif motion_type == "line" then
      start = Location.new(start.line, 0)
      -- We add 1 because Range is end-exclusive,
      -- and we want the entire line to be included in the range.
      stop = Location.of_line_end(stop.line) + 1
    end
    return range.new(start, stop)
  end
  return nil
end

-- Get the range of a line.
-- If no `line` is given, uses the current cursor line.
---@param line integer? A 0-indexed line number.
---@return occurrence.Range
function range.of_line(line)
  local start = Location.of_line_start(line)
  -- We add 1 because Range is end-exclusive,
  -- and we want the entire line to be included in the range.
  local stop = Location.of_line_end(line) + 1
  return range.new(start, stop)
end

-- Get the range of the current buffer.
---@return occurrence.Range
function range.of_buffer()
  local line_count = vim.api.nvim_buf_line_count(0)
  local start = Location.new(0, 0)
  -- We add 1 because Range is end-exclusive,
  -- and we want the entire buffer to be included in the range.
  local stop = Location.of_line_end(line_count - 1) + 1
  return range.new(start, stop)
end

-- Create a new `Range` from a `Range:serialize()` string.
---@param str string
---@return occurrence.Range
function range.deserialize(str)
  local start, stop = str:match("^(.+)%:%:(.+)$")
  return range.new(Location.deserialize(start), Location.deserialize(stop))
end

-- Serializes the `Range` to a string.
-- For a pretty-printed representation, use `tostring(Range)`.
---@return string
function Range:serialize()
  return table.concat({ self.start:serialize(), self.stop:serialize() }, "::")
end

-- Returns a plain table representation of the given `Range`.
-- The table has four elements: `{ start.line, start.col, stop.line, stop.col }`.
---@return integer[]
function Range:totable()
  return vim.list_slice(self)
end

-- Transpose this range to a new starting location.
---@param start occurrence.Location
---@return occurrence.Range
function Range:move(start)
  local line_diff = start.line - self.start.line
  local col_diff = start.col - self.start.col
  return range.new(start, self.stop:add(line_diff, col_diff))
end

-- Compare the given `Location` or `Range` to this `Range`.
--
-- A `Location` is considered to be contained if it is greater than
-- or equal to the start location, and less than the stop location.
--
-- A `Range` is considered to be contained if its start location
-- is greater than or equal to the start location, and its stop location
-- is less than or equal to the stop location.
---@param other occurrence.Range | occurrence.Location
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
---@param other occurrence.Range
---@return boolean
function Range:eq(other)
  return self.start == other.start and self.stop == other.stop
end

return range

