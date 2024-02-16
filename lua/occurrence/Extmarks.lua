local Location = require("occurrence.Location")
local Range = require("occurrence.Range")

local NS = vim.api.nvim_create_namespace("Occurrence")

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

-- A map of `Range` objects to extmark ids.
---@class Extmarks
local Extmarks = {}

function Extmarks:new()
  return setmetatable({}, { __index = self })
end

-- Check if there is an extmark for the given id or `Range`.
---@param id_or_range? number | Range
function Extmarks:has(id_or_range)
  if id_or_range == nil then
    return false
  elseif type(id_or_range) == "number" then
    return self[id_or_range] ~= nil
  else
    return self[id_or_range:serialize()] ~= nil
  end
end

-- Add an extmark and highlight for the given `Range`.
---@param buffer integer
--@param range Range
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
---@param id_or_range number | Range
---@return Range | nil
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
    return Range:deserialize(key):move(Location:new(unpack(loc)))
  end
end

-- Remove an extmark and highlight for the given `Range` or extmark id.
--
-- Note that this is different from `Extmarks:del_within()` in that,
-- if given a range, it will only remove an extmark that
-- exactly matches the given range.
--
---@param buffer number
---@param id_or_range number | Range
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

-- Remove all extmarks and highlights within the given `Range`.
--
-- Note that this is different from `Extmarks:del()` in that it can
-- remove multiple extmarks within the given range.
function Extmarks:del_within(buffer, range)
  -- Try the exact match delete first.
  if self:del(buffer, range) then
    return true
  end

  local success = false
  for key, extmark in pairs(self) do
    if range:contains(Range:deserialize(key)) then
      vim.api.nvim_buf_del_extmark(buffer, NS, extmark)
      self[self[key]] = nil
      self[key] = nil
      success = true
    end
  end
  return success
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
---@param opts? { range?: Range, reverse?: boolean }
---@return fun(): Range?, Range? next_extmark
function Extmarks:iter(buffer, opts)
  local range = opts and opts.range or Range:new(Location:new(0, 0), Location:new(vim.fn.line("$"), 0))
  ---@type Location | nil
  local start = opts and opts.reverse and range.stop or range.start
  local stop = opts and opts.reverse and range.start or range.stop

  -- Keep track of the last start location to avoid infinite loops
  -- when there are no more extmarks to traverse.
  local laststart

  local function next_extmark()
    if start == nil then
      return
    end

    -- Avoid infinite loops.
    if laststart ~= nil and start == laststart then
      return
    end

    --- List of (extmark_id, row, col) tuples in traversal order.
    local extmarks = vim.api.nvim_buf_get_extmarks(buffer, NS, start:to_extmarkpos(), stop:to_extmarkpos(), {})

    vim.print(tostring(start), tostring(stop))
    vim.print(extmarks)
    if next(extmarks) then
      local id, row, col = unpack(extmarks[1])
      local original_range = Range:deserialize(self[id])
      local current_location = Location:from_extmarkpos({ row, col })
      if original_range ~= nil and current_location ~= nil then
        -- Update the start position for the next iteration.
        laststart = start
        start = original_range.stop
        return original_range, original_range:move(current_location)
      end
    end
  end

  return next_extmark
end

return Extmarks
