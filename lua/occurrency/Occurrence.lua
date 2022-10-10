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

-- The internal state store for an Occurrence.
---@class OccurrenceState
---@field buffer integer The buffer in which the occurrence was found.
---@field span integer The number of bytes in the occurrence.
---@field pattern? string The pattern that was used to find the occurrence.
---@field range? Range The range of the occurrence.

-- Get a string key for the occurrence location.
---@param location Location
local function mark_key(location)
  return tostring(location)
end

---@class Marks
local Marks = {}

function Marks:new()
  return setmetatable({}, { __index = self })
end

-- Check if there is a mark at the given location.
---@param location? Location
function Marks:has_pos(location)
  return location and self[mark_key(location)] ~= nil
end

-- Add a mark and highlight for the current occurrence.
---@param state OccurrenceState
---@return boolean added Whether a mark was added.
function Marks:add(state)
  assert(state.range, "Occurrence has no match")
  local key = mark_key(state.range.start)

  if key and self[key] == nil then
    self[key] = vim.api.nvim_buf_set_extmark(state.buffer, NS, state.range.start.line, state.range.start.col, {
      end_row = state.range.stop.line,
      end_col = state.range.stop.col,
      hl_group = OCCURRENCE_HL_GROUP,
      hl_mode = "combine",
    })
    return true
  end
  return false
end

-- Remove a mark and highlight for the current occurrence.
---@param state OccurrenceState
---@return boolean deleted Whether a mark was removed.
function Marks:del(state)
  assert(state.range, "Occurrence has no match")
  local key = mark_key(state.range.start)
  if key and self[key] ~= nil then
    vim.api.nvim_buf_del_extmark(state.buffer, NS, self[key])
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
  local pattern = state.pattern
  assert(pattern, "Occurrence has not been initialized with a pattern")
  local buffer = state.buffer
  assert(buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
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

  local next_match = Location:from_searchpos(vim.fn.searchpos(pattern, flags))

  -- If searching for marked occurrences, keep searching until we find one.
  if next_match and opts.marked then
    local marks = MARKS_CACHE[self]
    if not marks:has_pos(next_match) then
      local start_match = next_match
      repeat
        next_match = Location:from_searchpos(vim.fn.searchpos(pattern, flags))
      until not next_match or marks:has_pos(next_match) or next_match == start_match
    end
  end

  if next_match then
    state.range = Range:new(next_match, next_match + state.span)
    if not opts.move then
      cursor:restore() -- restore cursor position.
    end
    return true
  else
    log.debug("No matches found for pattern:", pattern, "Restoring cursor position")
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
  local pattern = state.pattern
  assert(pattern, "Occurrence has not been initialized with a pattern")
  local buffer = state.buffer
  assert(buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursor = Cursor:save() -- store cursor position before searching.

  local next_match = Location:from_searchpos(vim.fn.searchpos(pattern, "c"))
  local prev_match = Location:from_searchpos(vim.fn.searchpos(pattern, "bc"))

  -- If searching for marked occurrences, keep searching until we find one in each direction.
  if opts.marked then
    local marks = MARKS_CACHE[self]
    if next_match then
      if not marks:has_pos(next_match) then
        repeat
          next_match = Location:from_searchpos(vim.fn.searchpos(pattern))
        until not next_match or marks:has_pos(next_match)
      end
    end
    if prev_match then
      if not marks:has_pos(prev_match) then
        repeat
          prev_match = Location:from_searchpos(vim.fn.searchpos(pattern, "b"))
        until not prev_match or marks:has_pos(prev_match)
      end
    end
  end

  if not next_match and not prev_match then
    log.debug("No matches found for pattern:", pattern, "Restoring cursor position")
    cursor:restore() -- restore cursor position after failed search.
    return false
  elseif next_match and prev_match then
    if next_match == prev_match then
      state.range = Range:new(next_match, next_match + state.span)
    elseif cursor.location:distance(prev_match) < cursor.location:distance(next_match) then
      state.range = Range:new(prev_match, prev_match + state.span)
    else
      state.range = Range:new(next_match, next_match + state.span)
    end
  elseif next_match then
    state.range = Range:new(next_match, next_match + state.span)
  elseif prev_match then
    state.range = Range:new(prev_match, prev_match + state.span)
  end

  if not opts.move then
    cursor:restore() -- restore cursor position.
  end
  return true
end

-- Mark the current occurrence.
---@return boolean marked Whether the occurrence was marked.
function Occurrence:mark()
  local state = STATE_CACHE[self]
  return MARKS_CACHE[self]:add(state)
end

-- Unmark the current occurrence.
---@return boolean unmarked Whether the occurrence was unmarked.
function Occurrence:unmark()
  local state = STATE_CACHE[self]
  return MARKS_CACHE[self]:del(state)
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
