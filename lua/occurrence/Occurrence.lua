local Location = require("occurrence.Location")
local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")
local log = require("occurrence.log")

local NS = vim.api.nvim_create_namespace("Occurrence")

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

-- A weak-key map of Occurrence instances to their internal state stores.
---@type table<Occurrence, OccurrenceState>
local STATE_CACHE = setmetatable({}, {
  __mode = "k",
  __index = function()
    error("Occurrence has not been initialized")
  end,
})

-- A weak-key map of Occurrence instances to their extmarks.
---@type table<Occurrence, Extmarks>
local EXTMARKS_CACHE = setmetatable({}, {
  __mode = "k",
  __index = function()
    error("Occurrence has not been initialized")
  end,
})

---@param state OccurrenceState
---@param flags string
---@return Range | nil
local function search(state, flags)
  if state.pattern then
    local start = Location:from_pos(vim.fn.searchpos(state.pattern, flags))
    if start then
      return Range:new(start, start + state.span)
    end
  end
end

-- The internal state store for an Occurrence.
---@class OccurrenceState
---@field buffer integer The buffer in which the occurrence was found.
---@field span integer The number of bytes in the occurrence.
---@field pattern? string The pattern that was used to find the occurrence.

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

-- A stateful representation of an occurrence of a pattern in a buffer.
---@class Occurrence: OccurrenceState
local Occurrence = {}

local OCCURRENCE_META = {
  __index = function(self, key)
    if rawget(self, key) ~= nil then
      return rawget(self, key)
    elseif Occurrence[key] ~= nil then
      return Occurrence[key]
    else
      local state = STATE_CACHE[self]
      if state[key] ~= nil then
        return state[key]
      end
    end
  end,
  __newindex = function(self, key, value)
    local state = STATE_CACHE[self]
    if rawget(self, key) == nil and state[key] ~= nil then
      error("Cannot set readonly field " .. key)
    else
      rawset(self, key, value)
    end
  end,
}

---@param buffer? integer
---@param text? string
---@param opts? { is_word: boolean }
---@return Occurrence
function Occurrence:new(buffer, text, opts)
  local occurrence = {}
  ---@diagnostic disable-next-line: missing-fields
  STATE_CACHE[occurrence] = { buffer = buffer or vim.api.nvim_get_current_buf() }
  EXTMARKS_CACHE[occurrence] = Extmarks:new()
  self.set(occurrence, text, opts)
  return setmetatable(occurrence, OCCURRENCE_META)
end

-- Move the cursor to the nearest occurrence.
--
-- By default the nearest occurrence in absolute terms will be matched,
-- including an occurrence at the cursor position, or an occurrence behind the cursor,
-- if it is aboslutely closer than the next occurrence after the cursor.
--
-- If `marked` is `true` (default is `false`), the search will only consider occurrences that have been marked.
-- If `wrap` is `true` (default is `false`), the search will wrap around the buffer.
-- If `direction` is 'forward', then the search will proceed to the nearest occurrence after the cursor position.
-- If `direction` is 'backward', then the search will scan back to the nearest occurrence before the cursor position.
-- For both directions, a match directly at the cursor position will be ignored.
---@param opts? { direction?: 'forward' | 'backward', marked?: boolean, wrap?: boolean }
---@return Range | nil
function Occurrence:match_cursor(opts)
  opts = vim.tbl_extend("force", { direction = nil, marked = false, wrap = false }, opts or {})
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  assert(state.pattern, "Occurrence has not been initialized with a pattern")
  assert(state.buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursor = Cursor:save() -- store cursor position before searching.

  local flags = opts.wrap and "nw" or "nW"

  local next_match
  local prev_match

  if opts.direction == "forward" then
    next_match = search(state, flags)
  elseif opts.direction == "backward" then
    prev_match = search(state, "b" .. flags)
  else
    next_match = search(state, "c" .. flags)
    prev_match = search(state, "b" .. flags)
  end

  -- If `marked` is `true`, keep searching until
  -- we find a marked occurrence in each direction.
  if opts.marked then
    local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
    if next_match and not extmarks:has(next_match) then
      local start = next_match
      repeat
        cursor:move(next_match.start)
        next_match = search(state, flags)
      until not next_match or extmarks:has(next_match) or next_match == start
    end
    if prev_match and not extmarks:has(prev_match) then
      local start = prev_match
      repeat
        cursor:move(prev_match.start)
        prev_match = search(state, "b" .. flags)
      until not prev_match or extmarks:has(prev_match) or prev_match == start
    end
  end

  local match = next_match or prev_match

  -- If we found matches in both directions, choose the closest match,
  -- with a bias toward matches that contain the cursor.
  if next_match and prev_match and next_match ~= prev_match then
    if next_match:contains(cursor.location) then
      match = next_match
    elseif prev_match:contains(cursor.location) then
      match = prev_match
    else
      local prev_dist = math.min(cursor.location:distance(prev_match.start), cursor.location:distance(prev_match.stop))
      local next_dist = math.min(cursor.location:distance(next_match.start), cursor.location:distance(next_match.stop))
      match = prev_dist < next_dist and prev_match or next_match
    end
  end

  if not match then
    cursor:restore() -- restore cursor position if no match was found.
  else
    cursor:move(match.start)
    return match
  end
end

-- Mark the occurrences contained within the given `Range`.
---@param range Range
---@return boolean marked Whether occurrences were marked.
function Occurrence:mark(range)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  local success = false
  for match in self:matches(range) do
    if extmarks:add(state.buffer, match) then
      success = true
    end
  end
  return success
end

-- Unmark the occurrences contained within the given `Range`.
---@param range Range
---@return boolean unmarked Whether occurrences were unmarked.
function Occurrence:unmark(range)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  return extmarks:del_within(state.buffer, range)
end

-- Whether or not the buffer contains at least one match for the occurrence.
function Occurrence:has_matches()
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  if not state.pattern then
    return false
  end
  return vim.fn.search(state.pattern, "ncw") ~= 0
end

-- Get an iterator of matching occurrence ranges.
-- If `range` is provided, only yields the occurrences contained within the given `Range`.
---@param range? Range
---@return fun(): Range next_match
function Occurrence:matches(range)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  local location = range and range.start or Location:new(0, 0)
  local match
  local function next_match()
    local cursor = Cursor:save()
    cursor:move(location)
    match = search(state, match and "W" or "cW")
    cursor:restore()
    if match and (not range or range:contains(match)) then
      location = match.start
      return match
    end
  end
  return next_match
end

-- Get an iterator of the marked occurrence ranges.
-- If `range` is provided, only yields the marked occurrences contained within the given `Range`.
--
-- The iterator yields two `Range` values for each marked occurrence:
-- - The orginal range of the marked occurrence.
--   This can be used to unmark the occurrence, e.g., `occurrence:unmark(original_range)`.
-- - The current 'live' range of the marked occurrence.
--   This can be used to make edits to the buffer, e.g., with `vim.api.nvim_buf_set_text(...)`.
---@param range? Range
---@return fun(): Range, Range next_mark
function Occurrence:marks(range)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  local key
  local function next_mark()
    key = next(marks, key)
    if key ~= nil then
      local marked_range = Range:deserialize(key)
      local current_range = marks:get(state.buffer, marked_range)
      assert(current_range, "Marked range not found in buffer")
      if range and range:contains(marked_range) then
        return marked_range, current_range
      elseif range then
        return next_mark()
      else
        return marked_range, current_range
      end
    end
  end
  return next_mark
end

-- Set the text to search for.
-- If the `is_word` option is set, the text will only match when surrounded with word boundaries.
---@param text? string
---@param opts? { is_word: boolean }
function Occurrence:set(text, opts)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")

  -- Clear all extmarks and highlights.
  EXTMARKS_CACHE[self] = Extmarks:new()
  vim.api.nvim_buf_clear_namespace(state.buffer, NS, 0, -1)

  if text == nil then
    state.pattern = nil
    state.span = 0
  else
    state.pattern = opts and opts.is_word and string.format([[\V\<%s\>]], text) or string.format([[\V%s]], text)
    state.span = #text
  end
end

return Occurrence
