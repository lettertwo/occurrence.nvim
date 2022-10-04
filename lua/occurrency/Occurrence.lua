local log = require("occurrency.log")

-- The internal state store for an Occurrence.
---@class OccurrenceState
---@field buffer integer The buffer in which the occurrence was found.
---@field span integer The number of bytes in the occurrence.
---@field pattern? string The pattern that was used to find the occurrence.
---@field line? integer The line on which the occurrence starts. 0-indexed.
---@field col? integer The column on which the occurrence starts. 0-indexed.

-- A stateful representation of an occurrence of a pattern in a buffer.
---@class Occurrence: OccurrenceState
local Occurrence = {}

-- A weak-key map of Occurrence instances to their internal state stores.
---@type table<Occurrence, OccurrenceState>
local STATE_CACHE = setmetatable({}, { __mode = "k" })

local OCCURRENCE_META = {
  __index = function(self, key)
    if rawget(self, key) ~= nil then
      return rawget(self, key)
    elseif Occurrence[key] ~= nil then
      return Occurrence[key]
    else
      local state = STATE_CACHE[self]
      assert(state, "Occurrence has not been initialized")
      if state[key] ~= nil then
        return state[key]
      elseif key == "line" or key == "col" then -- If the occurrence doesn't have match yet, try to find one.
        self:next()
        return state[key]
      end
    end
  end,
  __newindex = function(self, key, value)
    local state = STATE_CACHE[self]
    assert(state, "Occurrence has not been initialized")
    if rawget(self, key) == nil and state[key] ~= nil then
      error("Cannot set readonly field " .. key)
    else
      rawset(self, key, value)
    end
  end,
}

---FIXME: We cannot simply extend OccurrenceState because `self` ends up being Occcurrence.

---@param buffer? integer
---@param text? string
---@param opts? { is_word: boolean }
---@return Occurrence
function Occurrence:new(buffer, text, opts)
  local occurrence = {}
  STATE_CACHE[occurrence] = { buffer = buffer or vim.api.nvim_get_current_buf() }
  self.set(occurrence, text, opts)
  return setmetatable(occurrence, OCCURRENCE_META)
end

-- Move to the next occurrence in the buffer.
function Occurrence:next()
  local state = STATE_CACHE[self]
  assert(state, "Occurrence has not been initialized")
  local pattern = state.pattern
  assert(pattern, "Occurrence has not been initialized with a pattern")
  local buffer = state.buffer
  assert(buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.
  local next_match

  if state.line and state.col then
    -- Move cursor to current occurrence, then find next match.
    vim.fn.setpos(".", { buffer, state.line + 1, state.col + 1, 0 })
    next_match = vim.fn.searchpos(pattern, "nw")
  else
    -- On first match, allow matching at the current position.
    next_match = vim.fn.searchpos(pattern, "cnw")
  end

  if not next_match then
    log.warn("No matches found for pattern: " .. pattern)
  else
    state.line = next_match[1] - 1
    state.col = next_match[2] - 1
  end

  vim.fn.setpos(".", cursorpos) -- restore cursor position after search.
end

-- Move to the previous occurrence in the buffer.
function Occurrence:previous()
  local state = STATE_CACHE[self]
  assert(state, "Occurrence has not been initialized")
  local pattern = state.pattern
  assert(pattern, "Occurrence has not been initialized with a pattern")
  local buffer = state.buffer
  assert(buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.
  local prev_match

  if state.line and state.col then
    -- Move cursor to current occurrence, then find previous match.
    vim.fn.setpos(".", { buffer, state.line + 1, state.col + 1, 0 })
    prev_match = vim.fn.searchpos(pattern, "bnw")
  else
    -- On first match, allow matching at the current position.
    prev_match = vim.fn.searchpos(pattern, "bcnw")
  end

  if not prev_match then
    log.warn("No matches found for pattern: " .. pattern)
  else
    state.line = prev_match[1] - 1
    state.col = prev_match[2] - 1
  end

  vim.fn.setpos(".", cursorpos) -- restore cursor position after search.
end

-- Set the text to search for.
-- If the `is_word` option is set, the text will only match when surrounded with word boundaries.
---@param text? string
---@param opts? { is_word: boolean }
function Occurrence:set(text, opts)
  local state = STATE_CACHE[self]
  assert(state, "Occurrence has not been initialized")
  if text == nil then
    state.pattern = nil
    state.span = 0
  else
    state.pattern = opts and opts.is_word and string.format([[\V\<%s\>]], text) or string.format([[\V%s]], text)
    state.span = #text
  end
  state.line = nil
  state.col = nil

  -- If we have a pattern to search, find the first occurrence.
  if state.pattern then
    self:next()
  end
end

return Occurrence
