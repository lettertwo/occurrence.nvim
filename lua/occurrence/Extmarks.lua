local Location = require("occurrence.Location")
local Range = require("occurrence.Range")

---@module 'occurrence.Extmarks'
local extmarks = {}

local NS = vim.api.nvim_create_namespace("Occurrence")

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

-- A map of `Range` objects to extmark ids.
---@class occurrence.Extmarks
local Extmarks = {}

---@return occurrence.Extmarks
function extmarks.new()
  return setmetatable({}, { __index = Extmarks })
end

-- Check if there is an extmark for the given id or `Range`.
---@param id_or_range? number | occurrence.Range
---@return boolean
function Extmarks:has(id_or_range)
  if id_or_range == nil then
    return false
  elseif type(id_or_range) == "number" then
    return self[id_or_range] ~= nil
  else
    return self[id_or_range:serialize()] ~= nil
  end
end

-- Check if there are any extmarks in the given range.
-- If no range is given, checks if there are any extmarks at all.
---@param range? occurrence.Range
---@return boolean
function Extmarks:has_any(range)
  if range ~= nil then
    local iter = self:iter(0, { range = range })
    return iter() ~= nil
  end
  return next(self) ~= nil
end

-- Add an extmark and highlight for the given `Range`.
---@param buffer integer
---@param range occurrence.Range
---@return boolean added Whether an extmark was added.
function Extmarks:add(buffer, range)
  local key = range:serialize()

  if key and self[key] == nil then
    local id = vim.api.nvim_buf_set_extmark(buffer, NS, range.start.line, range.start.col, {
      end_row = range.stop.line,
      end_col = range.stop.col,
      hl_group = OCCURRENCE_HL_GROUP,
      hl_mode = "combine",
    })
    assert(self[id] == nil, "Duplicate extmark id")
    self[key] = id
    self[id] = key
    return true
  end
  return false
end

-- Get the current `Range` for the extmark originally added at the given `Range`.
-- This is useful for, e.g., cascading edits to the buffer at marked occurrences.
---@param buffer integer
---@param id_or_range number | occurrence.Range
---@return occurrence.Range?
function Extmarks:get(buffer, id_or_range)
  local key, id
  if type(id_or_range) == "number" then
    key = self[id_or_range]
    id = id_or_range
  else
    key = id_or_range:serialize()
    id = self[key]
  end

  if id ~= nil and key ~= nil then
    local loc = vim.api.nvim_buf_get_extmark_by_id(buffer, NS, id, {})
    assert(next(loc), "Unexpected missing extmark")
    return Range.deserialize(key):move(Location.new(unpack(loc)))
  end
end

-- Remove an extmark and highlight for the given `Range` or extmark id.
--
-- Note that if given a range, it will only remove an extmark
-- that exactly matches the range.
--
---@param buffer number
---@param id_or_range number | occurrence.Range
---@return boolean deleted Whether an extmark was removed.
function Extmarks:del(buffer, id_or_range)
  local key, id
  if type(id_or_range) == "number" then
    key = self[id_or_range]
    id = id_or_range
  else
    key = id_or_range:serialize()
    id = self[key]
  end
  if key ~= nil and id ~= nil then
    vim.api.nvim_buf_del_extmark(buffer, NS, id)
    self[id] = nil
    self[key] = nil
    return true
  end
  return false
end

-- Get an iterator of the extmarks for the given `buffer` and optional `range`.
-- If the `range` option is provided, only yields the extmarks contained within the given `Range`.
-- If the `reverse` option is `true` (default is `false`), yields the extmarks in reverse order.
--
-- The iterator yields a tuple of two `Range` values for each extmark:
-- - The orginal range of the extmark.
-- - The current 'live' range of the extmark.
--
---@param buffer integer
---@param opts? { range?: occurrence.Range, reverse?: boolean }
---@return fun(): occurrence.Range?, occurrence.Range? next_extmark
function Extmarks:iter(buffer, opts)
  local range = opts and opts.range or Range.new(Location.new(0, 0), Location.new(vim.fn.line("$"), 0))
  -- If `reverse` is true, invert the start and stop locations.
  local start = opts and opts.reverse and range.stop or range.start
  local stop = opts and opts.reverse and range.start or range.stop

  --- List of (extmark_id, row, col) tuples in traversal order.
  --- NOTE: If `end` is less than `start`, marks are returned in reverse order.
  local marks = vim.api.nvim_buf_get_extmarks(buffer, NS, start:to_extmarkpos(), stop:to_extmarkpos(), {})
  local index = 1

  local function next_extmark()
    local mark = marks[index]
    index = index + 1
    if mark then
      local id = mark[1]
      local original_range = Range.deserialize(self[id])
      local current_location = Location.from_extmarkpos(vim.api.nvim_buf_get_extmark_by_id(buffer, NS, id, {}))
      if original_range ~= nil and current_location ~= nil then
        return original_range, original_range:move(current_location)
      end
    end
  end

  return next_extmark
end

return extmarks
