local log = require("occurrency.log")

-- The internal state store for an Occurrence.
---@class OccurrenceState
---@field buffer integer The buffer in which the occurrence was found.
---@field span integer The number of bytes in the occurrence.
---@field has_match boolean Whether the occurrence has a match.
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
      elseif key == "has_match" then -- If the occurrence doesn't have match yet, try to find one.
        self:next()
        return state[key] or false
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
-- If `wrap` is `true` (default is `true`), the search will wrap around the end of the buffer.
-- If `nearest` is `true` (default is `false`), the search will move to next occurrence after to the cursor
-- If `move` is `true` (default is `false`), the cursor will be moved to the next occurrence.
-- instead of the next occurrence after the current occurrence.
---@param opts? { wrap?: boolean, nearest?: boolean, move?: boolean }
function Occurrence:next(opts)
  opts = vim.tbl_extend("force", { wrap = true, nearest = false, move = false }, opts or {})
  local state = STATE_CACHE[self]
  assert(state, "Occurrence has not been initialized")
  local pattern = state.pattern
  assert(pattern, "Occurrence has not been initialized with a pattern")
  local buffer = state.buffer
  assert(buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.

  local flags = opts.move and "" or "n"
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

-- Move to the previous occurrence in the buffer.
-- If `wrap` is `true` (default is `true`), the search will wrap around the end of the buffer.
-- If `nearest` is `true` (default is `false`), the search will move to previous occurrence before the cursor
-- If `move` is `true` (default is `false`), the cursor will be moved to the previous occurrence.
-- instead of the occurrence before the current occurrence.
---@param opts? { wrap?: boolean, nearest?: boolean, move?: boolean }
function Occurrence:previous(opts)
  opts = vim.tbl_extend("force", { wrap = true, nearest = false, move = false }, opts or {})
  local state = STATE_CACHE[self]
  assert(state, "Occurrence has not been initialized")
  local pattern = state.pattern
  assert(pattern, "Occurrence has not been initialized with a pattern")
  local buffer = state.buffer
  assert(buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.

  local flags = opts.move and "b" or "nb"
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

  local prev_match = vim.fn.searchpos(pattern, flags)
  if prev_match then
    state.has_match = true
    state.line = prev_match[1] - 1
    state.col = prev_match[2] - 1
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
  state.has_match = nil

  -- If we have a pattern to search, find the first occurrence.
  if state.pattern then
    self:next()
  end
end

return Occurrence
