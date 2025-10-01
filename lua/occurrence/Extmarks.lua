local Disposable = require("occurrence.Disposable")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")

local resolve_buffer = require("occurrence.resolve_buffer")

---@module 'occurrence.Extmarks'
local extmarks = {}

local NS = vim.api.nvim_create_namespace("Occurrence")

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

-- A map of `Range` objects to extmark ids.
---@class occurrence.Extmarks: occurrence.Disposable
---@field buffer integer The buffer the extmarks are in.
local Extmarks = {}

---@param buffer? integer
---@return occurrence.Extmarks
function extmarks.new(buffer)
  buffer = resolve_buffer(buffer, true)
  local disposable = Disposable.new()
  local self = setmetatable({}, {
    __index = function(tbl, key)
      if rawget(tbl, key) ~= nil then
        return rawget(tbl, key)
      elseif key == "buffer" then
        return buffer
      elseif Extmarks[key] then
        return Extmarks[key]
      elseif disposable[key] ~= nil then
        return disposable[key]
      end
    end,
  })
  disposable:add(function()
    self:clear()
  end)
  return self
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
  local iter = self:iter({ range = range })
  return iter() ~= nil
end

-- Add an extmark and highlight for the given `Range`.
---@param range occurrence.Range
---@return boolean added Whether an extmark was added.
function Extmarks:add(range)
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  local key = range:serialize()

  if key and self[key] == nil then
    local id = vim.api.nvim_buf_set_extmark(self.buffer, NS, range.start.line, range.start.col, {
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
---@param id_or_range number | occurrence.Range
---@return occurrence.Range?
function Extmarks:get(id_or_range)
  local key, id
  if type(id_or_range) == "number" then
    key = self[id_or_range]
    id = id_or_range
  else
    key = id_or_range:serialize()
    id = self[key]
  end

  if id ~= nil and key ~= nil then
    local loc = vim.api.nvim_buf_get_extmark_by_id(self.buffer, NS, id, {})
    assert(next(loc), "Unexpected missing extmark")
    return Range.deserialize(key):move(Location.new(unpack(loc)))
  end
end

-- Remove an extmark and highlight for the given `Range` or extmark id.
--
-- Note that if given a range, it will only remove an extmark
-- that exactly matches the range.
--
---@param id_or_range number | occurrence.Range
---@return boolean deleted Whether an extmark was removed.
function Extmarks:del(id_or_range)
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  local key, id
  if type(id_or_range) == "number" then
    key = self[id_or_range]
    id = id_or_range
  else
    key = id_or_range:serialize()
    id = self[key]
  end
  if key ~= nil and id ~= nil then
    vim.api.nvim_buf_del_extmark(self.buffer, NS, id)
    self[id] = nil
    self[key] = nil
    return true
  end
  return false
end

function Extmarks:clear()
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  vim.api.nvim_buf_clear_namespace(self.buffer, NS, 0, -1)
  for k in pairs(self) do
    self[k] = nil
  end
end

-- Get an iterator of extmarks.
-- If a `range` is provided, only yields the extmarks contained within the given `Range`.
-- If the `reverse` option is `true` (default is `false`), yields the extmarks in reverse order.
--
-- The iterator yields a tuple of two `Range` values for each extmark:
-- - The orginal range of the extmark.
-- - The current 'live' range of the extmark.
--
---@param opts? { range?: occurrence.Range, reverse?: boolean }
---@return fun(): occurrence.Range?, occurrence.Range? next_extmark
function Extmarks:iter(opts)
  local range = opts and opts.range or Range.new(Location.new(0, 0), Location.new(vim.fn.line("$"), 0))
  -- If `reverse` is true, invert the start and stop locations.
  local start = opts and opts.reverse and range.stop or range.start
  local stop = opts and opts.reverse and range.start or range.stop

  --- List of (extmark_id, row, col) tuples in traversal order.
  --- NOTE: If `end` is less than `start`, marks are returned in reverse order.
  local marks = vim.api.nvim_buf_get_extmarks(self.buffer, NS, start:to_extmarkpos(), stop:to_extmarkpos(), {})
  local index = 1

  local function next_extmark()
    local mark = marks[index]
    index = index + 1
    if mark then
      local id = mark[1]
      local original_range = Range.deserialize(self[id])
      local current_location = Location.from_extmarkpos(vim.api.nvim_buf_get_extmark_by_id(self.buffer, NS, id, {}))
      if original_range ~= nil and current_location ~= nil then
        return original_range, original_range:move(current_location)
      end
    end
  end

  return next_extmark
end

return extmarks
