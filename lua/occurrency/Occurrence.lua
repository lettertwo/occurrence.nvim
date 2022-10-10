local Location = require("occurrency.Location")
local Cursor = require("occurrency.Cursor")
local Range = require("occurrency.Range")
local log = require("occurrency.log")

local NS = vim.api.nvim_create_namespace("Occurrency")

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

-- A weak-key map of Occurrence instances to their marks.
---@type table<Occurrence, Marks>
local MARKS_CACHE = setmetatable({}, {
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
    local start = Location:from_searchpos(vim.fn.searchpos(state.pattern, flags))
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
---@field range? Range The range of the occurrence.

-- A map of `Range` objects to extmark ids.
---@class Marks
local Marks = {}

function Marks:new()
  return setmetatable({}, { __index = self })
end

-- Check if there is a mark for the given range.
---@param range? Range
function Marks:has(range)
  return range and self[range:serialize()] ~= nil
end

-- Add a mark and highlight for the given `Range`.
---@param buffer integer
--@param range Range
---@return boolean added Whether a mark was added.
function Marks:add(buffer, range)
  local key = range:serialize()

  if key and self[key] == nil then
    self[key] = vim.api.nvim_buf_set_extmark(buffer, NS, range.start.line, range.start.col, {
      end_row = range.stop.line,
      end_col = range.stop.col,
      hl_group = OCCURRENCE_HL_GROUP,
      hl_mode = "combine",
    })
    return true
  end
  return false
end

-- Get the current `Range` for the mark originally added at the given `Range`.
-- This is useful for, e.g., cascading edits to the buffer at marked occurrences.
---@param buffer integer
---@param range Range
---@return Range | nil
function Marks:get(buffer, range)
  local id = self[range:serialize()]
  if id ~= nil then
    local loc = vim.api.nvim_buf_get_extmark_by_id(buffer, NS, id, {})
    if next(loc) then
      return range:move(Location:new(unpack(loc)))
    end
  end
end

-- Remove a mark and highlight for the given `Range`.
--
-- Note that this is different from `Marks:del_within()` in that it will
-- only remove a mark that exactly matches the given range.
---@param buffer integer
---@param range Range
---@return boolean deleted Whether a mark was removed.
function Marks:del(buffer, range)
  local key = range:serialize()
  if key and self[key] ~= nil then
    vim.api.nvim_buf_del_extmark(buffer, NS, self[key])
    self[key] = nil
    return true
  end
  return false
end

-- Remove all marks and highlights within the given `Range`.
--
-- Note that this is different from `Marks:del()` in that it can
-- remove multiple marks within the given range.
function Marks:del_within(buffer, range)
  -- Try the exact match delete first.
  if self:del(buffer, range) then
    return true
  end

  local success = false
  for key, mark in pairs(self) do
    if range:contains(Range:deserialize(key)) then
      vim.api.nvim_buf_del_extmark(buffer, NS, mark)
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
  STATE_CACHE[occurrence] = { buffer = buffer or vim.api.nvim_get_current_buf() }
  MARKS_CACHE[occurrence] = Marks:new()
  self.set(occurrence, text, opts)
  return setmetatable(occurrence, OCCURRENCE_META)
end

-- Find the next occurrence in the buffer.
--
-- If `reverse` is `true` (default is `false`), the search will proceed backwards.
-- If `wrap` is `true` (default is `true`), the search will wrap around the end of the buffer.
-- If `nearest` is `true` (default is `false`), the search will move to next occurrence relative to the cursor.
-- If `move` is `true` (default is `false`), the cursor will be moved to the next occurrence.
-- If `marked` is `true` (default is `false`), the search will only consider occurrences that have been marked.
---@param opts? { reverse?: boolean, wrap?: boolean, nearest?: boolean, move?: boolean, marked?: boolean }
function Occurrence:match(opts)
  opts = vim.tbl_extend(
    "force",
    { reverse = false, wrap = true, nearest = false, move = false, marked = false },
    opts or {}
  )
  local state = STATE_CACHE[self]
  assert(state.pattern, "Occurrence has not been initialized with a pattern")
  assert(state.buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursor = Cursor:save() -- store cursor position before searching.

  local flags = opts.reverse and "b" or ""
  flags = flags .. (opts.move and "" or "n")
  flags = flags .. (opts.wrap and "w" or "")
  flags = flags .. (state.range and "" or "c")

  if not opts.nearest then
    if state.range then
      -- Move cursor to current occurrence.
      cursor:move(state.range.start)
    else
      -- On first match, move cursor to the start of the buffer.
      cursor:move(Location:new(0, 0))
    end
  end

  local next_match = search(state, flags)

  -- If searching for marked occurrences, keep searching until we find one.
  if next_match and opts.marked then
    local marks = MARKS_CACHE[self]
    if not marks:has(next_match) then
      local start_match = next_match
      repeat
        next_match = search(state, flags)
      until not next_match or marks:has(next_match) or next_match == start_match
    end
  end

  if next_match then
    state.range = next_match
    if not opts.move then
      cursor:restore() -- restore cursor position.
    end
    return true
  else
    log.debug("No matches found for pattern:", state.pattern, "Restoring cursor position")
    state.range = nil
    cursor:restore() -- restore cursor position after failed search.
    return false
  end
end

-- Find the nearest occurrence to the cursor.
-- Has a bias toward the current line, but if the nearest occurrence
-- in absolute terms is behind the cursor, it will be matched.
--
-- If `move` is `true` (default is `false`), the cursor will be moved to the nearest occurrence.
-- If `marked` is `true` (default is `false`), the search will only consider occurrences that have been marked.
---@param opts? { move?: boolean, marked?: boolean }
function Occurrence:match_cursor(opts)
  opts = vim.tbl_extend("force", { move = false, marked = false }, opts or {})
  local state = STATE_CACHE[self]
  assert(state.pattern, "Occurrence has not been initialized with a pattern")
  assert(state.buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursor = Cursor:save() -- store cursor position before searching.

  local next_match = search(state, "c")
  local prev_match = search(state, "bc")

  -- If searching for marked occurrences, keep searching until we find one in each direction.
  if opts.marked then
    local marks = MARKS_CACHE[self]
    if next_match then
      if not marks:has(next_match) then
        repeat
          next_match = search(state, "W")
        until not next_match or marks:has(next_match)
      end
    end
    if prev_match then
      if not marks:has(prev_match) then
        repeat
          prev_match = search(state, "bW")
        until not prev_match or marks:has(prev_match)
      end
    end
  end

  if not next_match and not prev_match then
    log.debug("No matches found for pattern:", state.pattern, "Restoring cursor position")
    state.range = nil
    cursor:restore() -- restore cursor position after failed search.
    return false
  elseif next_match and prev_match then
    if next_match == prev_match then
      state.range = next_match
      -- TODO: Maybe compare the distance between the cursor and the start _and_ end of the matches?
    elseif cursor.location:distance(prev_match.start) < cursor.location:distance(next_match.start) then
      state.range = prev_match
    else
      state.range = next_match
    end
  elseif next_match then
    state.range = next_match
  elseif prev_match then
    state.range = prev_match
  end

  if not opts.move then
    cursor:restore() -- restore cursor position.
  end
  return true
end

-- Mark the current occurrence.
-- If `range` is provided, mark the occurrences contained within the given `Range` instead.
---@param range? Range
---@return boolean marked Whether the occurrence was marked.
function Occurrence:mark(range)
  local state = STATE_CACHE[self]
  if range then
    local success = false
    for match in self:matches(range) do
      if MARKS_CACHE[self]:add(state.buffer, match) then
        success = true
      end
    end
    return success
  else
    return MARKS_CACHE[self]:add(state.buffer, state.range)
  end
end

-- Unmark the current occurrence.
-- If `range` is provided, unmark the occurrences contained within the given `Range` instead.
---@param range? Range
---@return boolean unmarked Whether the occurrence was unmarked.
function Occurrence:unmark(range)
  local state = STATE_CACHE[self]
  return MARKS_CACHE[self]:del_within(state.buffer, range or state.range)
end

-- Get an iterator of matching occurrence ranges.
-- If `range` is provided, only yields the occurrences contained within the given `Range`.
---@param range? Range
---@return fun(): Range next_match
function Occurrence:matches(range)
  local state = STATE_CACHE[self]
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
-- The iterator yields two `Range` values for each mark:
-- - The orginal range of the marked occurrence.
--   This can be used to unmark the occurrence, e.g., `occurrence:unmark(original_range)`.
-- - The current 'live' range of the marked occurrence.
--   This can be used to make edits to the buffer, e.g., with `vim.api.nvim_buf_set_text(...)`.
---@param range? Range
---@return fun(): Range, Range next_mark
function Occurrence:marks(range)
  local state = STATE_CACHE[self]
  local marks = MARKS_CACHE[self]
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
  local state = STATE_CACHE[self]

  -- Clear all marks and highlights.
  MARKS_CACHE[self] = Marks:new()
  vim.api.nvim_buf_clear_namespace(state.buffer, NS, 0, -1)

  if text == nil then
    state.pattern = nil
    state.span = 0
  else
    state.pattern = opts and opts.is_word and string.format([[\V\<%s\>]], text) or string.format([[\V%s]], text)
    state.span = #text
  end
  state.range = nil

  -- If we have a pattern to search, find the first occurrence.
  if state.pattern then
    self:match()
  end
end

return Occurrence
