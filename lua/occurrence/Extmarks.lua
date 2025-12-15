local Disposable = require("occurrence.Disposable")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")

local resolve_buffer = require("occurrence.resolve_buffer")

---@module 'occurrence.Extmarks'
local extmarks = {}

-- Namespaces for extmarks
local MATCH_NS = vim.api.nvim_create_namespace("OccurrenceMatch")
local MARK_NS = vim.api.nvim_create_namespace("OccurrenceMark")
local CURRENT_NS = vim.api.nvim_create_namespace("OccurrenceCurrent")

-- Highlight groups
local MATCH_HLGROUP = "OccurrenceMatch"
local MARK_HLGROUP = "OccurrenceMark"
local CURRENT_HLGROUP = "OccurrenceCurrent"

-- Define default highlight groups on module load
-- OccurrenceMatch: for all occurrence matches (default: Search)
vim.api.nvim_set_hl(0, MATCH_HLGROUP, { default = true, link = "Search" })
-- OccurrenceMark: for marked occurrences (default: IncSearch)
vim.api.nvim_set_hl(0, MARK_HLGROUP, { default = true, link = "IncSearch" })
-- OccurrenceCurrent: for current occurrence under cursor (default: CurSearch)
vim.api.nvim_set_hl(0, CURRENT_HLGROUP, { default = true, link = "CurSearch" })

---@alias occurrence.ExtmarkType 'mark' | 'match'

-- A map of `Range` objects to extmark ids.
---@class occurrence.ExtmarkMap: occurrence.Disposable, { [string]: integer }, { [integer]: string }
---@field buffer integer The buffer the extmarks are in.
---@field ns integer The namespace the extmarks are in.
---@field hlgroup string The highlight group applied to the extmarks.
local ExtmarkMap = {}

---@param range occurrence.Range
---@return boolean added Whether an extmark was added.
function ExtmarkMap:add(range)
  assert(not self:is_disposed(), "Cannot use a disposed ExtmarkMap")
  local key = range:serialize()
  if key and self[key] == nil then
    local ok, id = pcall(vim.api.nvim_buf_set_extmark, self.buffer, self.ns, range.start.line, range.start.col, {
      end_row = range.stop.line,
      end_col = range.stop.col,
      hl_group = self.hlgroup,
      hl_mode = "combine",
    })
    if not ok then
      return false
    end
    assert(self[id] == nil, "Duplicate extmark id")
    self[key] = id
    self[id] = key
    return true
  end
  return false
end

---@param id_or_range number | occurrence.Range
function ExtmarkMap:del(id_or_range)
  assert(not self:is_disposed(), "Cannot use a disposed ExtmarkMap")
  local key, id
  if type(id_or_range) == "number" then
    key = self[id_or_range]
    id = id_or_range
  else
    key = id_or_range:serialize()
    id = self[key]
  end
  if key ~= nil and id ~= nil then
    vim.api.nvim_buf_del_extmark(self.buffer, self.ns, id)
    self[id] = nil
    self[key] = nil
    return true
  end
  return false
end

-- Get the current `Range` for the extmark originally added at the given `Range`.
-- This is useful for, e.g., cascading edits to the buffer at marked occurrences.
---@param id_or_range number | occurrence.Range
---@return occurrence.Range?
function ExtmarkMap:get(id_or_range)
  local key, id
  if type(id_or_range) == "number" then
    key = self[id_or_range]
    id = id_or_range
  else
    key = id_or_range:serialize()
    id = self[key]
  end

  if id ~= nil and key ~= nil then
    local loc = vim.api.nvim_buf_get_extmark_by_id(self.buffer, self.ns, id, {})
    assert(next(loc), "Unexpected missing extmark")
    return Range.deserialize(key):move(Location.new(unpack(loc)))
  end
end

-- Get an iterator of extmarks.
-- The iterator yields a tuple for each extmark of:
-- - The id of the extmark
-- - The current 'live' range of the extmark
---@param range? occurrence.Range
---@return fun(): number?, occurrence.Range? next_extmark
function ExtmarkMap:iter(range)
  range = range or Range.of_buffer()
  local start = range.start:to_extmarkpos()
  local stop = range.stop:to_extmarkpos()

  --- List of (extmark_id, row, col) tuples in traversal order.
  local marks = vim.api.nvim_buf_get_extmarks(self.buffer, self.ns, start, stop, { overlap = true })
  local index = 1

  local function next_extmark()
    local mark = marks[index]
    index = index + 1
    if mark then
      local id = mark[1]
      local original_range = Range.deserialize(self[id])
      if not range:contains(original_range) then
        return next_extmark()
      end
      local current_location =
        Location.from_extmarkpos(vim.api.nvim_buf_get_extmark_by_id(self.buffer, self.ns, id, {}))
      if original_range ~= nil and current_location ~= nil then
        return id, original_range:move(current_location)
      end
    end
  end

  return next_extmark
end

-- Check if there is an extmark for the given id or `Range`.
-- If no id or range is given, checks if there are any extmarks at all.
---@param id_or_range? number | occurrence.Range
---@return boolean
function ExtmarkMap:has(id_or_range)
  if id_or_range == nil then
    return #vim.api.nvim_buf_get_extmarks(self.buffer, self.ns, 0, -1, {}) > 0
  elseif type(id_or_range) == "number" then
    return self[id_or_range] ~= nil
  else
    return self[id_or_range:serialize()] ~= nil
  end
end

function ExtmarkMap:clear()
  assert(not self:is_disposed(), "Cannot use a disposed ExtmarkMap")
  vim.api.nvim_buf_clear_namespace(self.buffer, self.ns, 0, -1)
  for k in pairs(self) do
    self[k] = nil
  end
end

---@param buffer number
---@param ns number
---@param hlgroup string
---@return occurrence.ExtmarkMap
local function create_extmark_map(buffer, ns, hlgroup)
  buffer = resolve_buffer(buffer, true)
  local disposable = Disposable.new()
  local self = setmetatable({}, {
    __index = function(tbl, key)
      if rawget(tbl, key) ~= nil then
        return rawget(tbl, key)
      elseif key == "buffer" then
        return buffer
      elseif key == "ns" then
        return ns
      elseif key == "hlgroup" then
        return hlgroup
      elseif ExtmarkMap[key] then
        return ExtmarkMap[key]
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

-- A map of `Range` objects to extmark ids.
---@class occurrence.Extmarks: occurrence.Disposable
---@field buffer integer The buffer the extmarks are in.
---@field protected matches occurrence.ExtmarkMap Map of occurrence matches.
---@field protected marks occurrence.ExtmarkMap Map of marked occurrence matches.
---@field protected current occurrence.ExtmarkMap Map for current occurrence under cursor.
local Extmarks = {}

---@param buffer? integer
---@return occurrence.Extmarks
function extmarks.new(buffer)
  buffer = resolve_buffer(buffer, true)
  local disposable = Disposable.new()
  local self = setmetatable({
    matches = create_extmark_map(buffer, MATCH_NS, MATCH_HLGROUP),
    marks = create_extmark_map(buffer, MARK_NS, MARK_HLGROUP),
    current = create_extmark_map(buffer, CURRENT_NS, CURRENT_HLGROUP),
  }, {
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
  disposable:add(self.matches)
  disposable:add(self.marks)
  disposable:add(self.current)
  return self
end

-- Check if there is an extmark for the given id or `Range`.
---@param id_or_range? number | occurrence.Range
---@return boolean
function Extmarks:has_mark(id_or_range)
  return self.marks:has(id_or_range)
end

-- Check if there are any extmarks in the given range.
-- If no range is given, checks if there are any extmarks at all.
---@param range? occurrence.Range
---@return boolean
function Extmarks:has_any_marks(range)
  local iter = self.marks:iter(range)
  return iter() ~= nil
end

-- Add an match extmark and highlight for the given `Range`.
---@param range occurrence.Range
---@return boolean added Whether an extmark was added.
function Extmarks:add(range)
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  return self.matches:add(range)
end

-- Add an mark extmark and highlight for the given `Range`.
---@param range occurrence.Range
---@return boolean added Whether an extmark was added.
function Extmarks:mark(range)
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  self.matches:add(range)
  return self.marks:add(range)
end

-- Get the current `Range` for the extmark originally added at the given `Range`.
-- This is useful for, e.g., cascading edits to the buffer at marked occurrences.
---@param id_or_range number | occurrence.Range
---@return occurrence.Range?
function Extmarks:get_mark(id_or_range)
  return self.marks:get(id_or_range)
end

-- Remove a mark extmark and highlight for the given `Range` or extmark id.
--
-- Note that if given a range, it will only remove an extmark
-- that exactly matches the range.
--
---@param id_or_range number | occurrence.Range
---@return boolean deleted Whether an extmark was removed.
function Extmarks:unmark(id_or_range)
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  return self.marks:del(id_or_range)
end

function Extmarks:clear()
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  self.matches:clear()
  self.marks:clear()
  self.current:clear()
end

-- Get an iterator of mark extmarks.
-- If a `range` is provided, only yields the extmarks contained within the given `Range`.
-- The iterator yields a tuple for each extmark of:
-- - The id of the extmark
-- - The current 'live' range of the extmark
---@param range? occurrence.Range
---@return fun(): number?, occurrence.Range? next_extmark
function Extmarks:iter(range)
  return self.marks:iter(range)
end

---@param range? occurrence.Range
---@param count? integer
---@return [number, occurrence.Range][]
function Extmarks:collect(range, count)
  local marks = vim.iter(vim.iter(self:iter(range)):fold({}, function(acc, id, edit)
    table.insert(acc, { id, edit })
    return acc
  end))
  if count and count > 0 then
    marks = marks:take(count)
  end
  return marks:totable()
end

-- Clear the current occurrence highlight.
function Extmarks:clear_current()
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  self.current:clear()
end

-- Update the current occurrence highlight to the given cursor location.
-- If no location is given, uses the current cursor position.
---@param cursor? occurrence.Location
function Extmarks:update_current(cursor)
  assert(not self:is_disposed(), "Cannot use a disposed Extmarks")
  cursor = cursor or Location.of_cursor()

  self.current:clear()

  if cursor then
    for _, range in self:iter() do
      if range:contains(cursor) then
        self.current:add(range)
        break
      end
    end
  end
end

return extmarks
