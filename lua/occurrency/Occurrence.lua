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
---@field has_match boolean Whether the occurrence has a match.
---@field pattern? string The pattern that was used to find the occurrence.
---@field line? integer The line on which the occurrence starts. 0-indexed.
---@field col? integer The column on which the occurrence starts. 0-indexed.

-- Get a string key for the occurrence state.
---@param state OccurrenceState
local function mark_key(state)
  if state.has_match then
    return state.line .. state.col
  end
end

---@class Marks
local Marks = {}

function Marks:new()
  return setmetatable({}, { __index = self })
end

-- Check if there is a mark at the given position.
---@param pos integer[] A position as returned by `vim.fn.searchpos()`.
function Marks:has_pos(pos)
  return self[mark_key({
    has_match = true,
    line = pos[1] - 1,
    col = pos[2] - 1,
  })] ~= nil
end

-- Add a mark and highlight for the current occurrence.
---@param state OccurrenceState
---@return boolean Whether a mark was added.
function Marks:add(state)
  assert(state.has_match, "Occurrence has no match")
  local key = mark_key(state)
  if key and self[key] == nil then
    self[key] = vim.api.nvim_buf_set_extmark(state.buffer, NS, state.line, state.col, {
      end_line = state.line,
      end_col = state.col + state.span,
      hl_group = OCCURRENCE_HL_GROUP,
    })
    return true
  end
  return false
end

-- Remove a mark and highlight for the current occurrence.
---@param state OccurrenceState
---@return boolean Whether a mark was removed.
function Marks:del(state)
  assert(state.has_match, "Occurrence has no match")
  local key = mark_key(state)
  if key and self[key] ~= nil then
    vim.api.nvim_buf_del_extmark(state.buffer, NS, self[key])
    self[key] = nil
    return true
  end
  return false
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
      elseif key == "has_match" then -- If the occurrence doesn't have match yet, try to find one.
        self:match()
        return state[key] or false
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
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.

  local flags = opts.reverse and "b" or ""
  flags = flags .. (opts.move and "" or "n")
  flags = flags .. (opts.wrap and "w" or "")
  flags = flags .. (state.has_match and "" or "c")

  if not opts.nearest then
    if state.has_match then
      -- Move cursor to current occurrence.
      vim.fn.setpos(".", { buffer, state.line + 1, state.col + 1, 0 })
    else
      -- On first match, move cursor to the start of the buffer.
      vim.fn.setpos(".", { buffer, 1, 1, 0 })
    end
  end

  local next_match = vim.fn.searchpos(pattern, flags)

  -- If searching for marked occurrences, keep searching until we find one.
  if next_match and opts.marked then
    local marks = MARKS_CACHE[self]
    if not marks:has_pos(next_match) then
      local start_match = next_match
      repeat
        next_match = vim.fn.searchpos(pattern, flags)
      until not next_match
        or marks:has_pos(next_match)
        or (start_match[1] == next_match[1] and start_match[2] == next_match[2])
    end
  end

  if next_match then
    state.has_match = true
    state.line = next_match[1] - 1
    state.col = next_match[2] - 1
    if not opts.move then
      vim.fn.setpos(".", cursorpos) -- restore cursor position after search.
    end
    return true
  else
    log.debug("No matches found for pattern:", pattern, "Restoring cursor position")
    vim.fn.setpos(".", cursorpos) -- restore cursor position after failed search.
    return false
  end
end

-- Mark the current occurrence.
function Occurrence:mark()
  local state = STATE_CACHE[self]
  if MARKS_CACHE[self]:add(state) then
    state.marked = true
  end
end

-- Unmark the current occurrence.
function Occurrence:unmark()
  local state = STATE_CACHE[self]
  if MARKS_CACHE[self]:del(state) then
    state.marked = false
  end
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
  state.line = nil
  state.col = nil
  state.has_match = nil

  -- If we have a pattern to search, find the first occurrence.
  if state.pattern then
    self:match()
  end
end

return Occurrence
