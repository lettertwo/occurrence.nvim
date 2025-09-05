local Location = require("occurrence.Location")
local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")
local Extmarks = require("occurrence.Extmarks")
local log = require("occurrence.log")

---@module 'occurrence.Occurrence'
local occurrence = {}

local NS = vim.api.nvim_create_namespace("Occurrence")

-- A weak-key map of Occurrence instances to their internal state stores.
---@type table<occurrence.Occurrence, occurrence.OccurrenceState>
local STATE_CACHE = setmetatable({}, {
  __mode = "k",
  __index = function()
    error("Occurrence has not been initialized")
  end,
})

-- A weak-key map of Occurrence instances to their extmarks.
---@type table<occurrence.Occurrence, occurrence.Extmarks>
local EXTMARKS_CACHE = setmetatable({}, {
  __mode = "k",
  __index = function()
    error("Occurrence has not been initialized")
  end,
})

---@class occurrence.SearchFlags
---@field cursor? boolean Whether to accept a match at the cursor position.
---@field backward? boolean Whether to search backward.
---@field wrap? boolean Whether to wrap around the buffer.
local SearchFlags = {
  cursor = false,
  backward = false,
  wrap = false,
}

setmetatable(SearchFlags, {
  __newindex = function()
    error("SearchFlags is read-only")
  end,
  __call = function(self, opts)
    local new = vim.tbl_extend("force", self, opts or {})
    setmetatable(new, getmetatable(self))
    return new
  end,
  __tostring = function(flags)
    -- Always use 'n' to avoid moving the cursor.
    local result = "n" .. (flags.wrap and "w" or "W")
    if flags.cursor then
      result = "c" .. result
    end
    if flags.backward then
      result = "b" .. result
    end
    return result
  end,
})
---@param pattern string
---@param flags occurrence.SearchFlags
---@return occurrence.Range | nil
local function search(pattern, flags)
  local start = Location.from_pos(vim.fn.searchpos(pattern, tostring(SearchFlags(flags))))
  if start ~= nil then
    local cursor = Cursor.save()
    cursor:move(start)
    local matchend = Location.from_pos(vim.fn.searchpos(pattern, "nWe"))
    cursor:restore()
    if matchend == nil then
      return nil
    end
    return Range.new(start, matchend + 1)
  end
  return nil
end

---@param loc1 occurrence.Location
---@param loc2 occurrence.Location
local function char_dist(loc1, loc2)
  if loc1.line == loc2.line then
    return math.abs(loc1.col - loc2.col)
  end
  if loc1 > loc2 then
    loc2, loc1 = loc1, loc2
  end
  local lines = vim.api.nvim_buf_get_lines(0, loc1.line, loc2.line + 1, false)
  local chars = loc2.col
  if #lines > 1 then
    chars = chars + #lines[1] - loc1.col
    for i = 2, #lines - 1 do
      chars = chars + #lines[i]
    end
  end
  return chars
end

---@param state occurrence.OccurrenceState
---@param flags occurrence.SearchFlags
---@param cursor? occurrence.Location
---@param bounds? occurrence.Range
---@return occurrence.Range | nil
local function closest(state, flags, cursor, bounds)
  if #state.patterns == 1 then
    return search(state.patterns[1], flags)
  end
  if #state.patterns > 1 then
    local closest_match = nil
    cursor = assert(cursor or Location.of_cursor(), "cursor location not found")
    for i, pattern in ipairs(state.patterns) do
      local match = search(pattern, flags)
      if match and not closest_match then
        closest_match = match
      elseif match and closest_match then
        local match_dist = math.min(char_dist(cursor, match.start), char_dist(cursor, match.stop))
        local closest_match_dist =
          math.min(char_dist(cursor, closest_match.start), char_dist(cursor, closest_match.stop))

        -- If wrapping is enabled, we need to consider the distance to the bounds.
        if flags.wrap and bounds then
          if flags.backward then
            match_dist = math.min(match_dist, char_dist(cursor, bounds.start) + char_dist(bounds.stop, match.stop))
            closest_match_dist =
              math.min(closest_match_dist, char_dist(cursor, bounds.start) + char_dist(bounds.stop, closest_match.stop))
          else
            match_dist = math.min(match_dist, char_dist(cursor, bounds.stop) + char_dist(bounds.start, match.start))
            closest_match_dist = math.min(
              closest_match_dist,
              char_dist(cursor, bounds.stop) + char_dist(bounds.start, closest_match.start)
            )
          end
        end

        if match_dist < closest_match_dist then
          closest_match = match
        end
      end
    end
    return closest_match
  end
end

-- The internal state store for an Occurrence.
---@class occurrence.OccurrenceState
---@field patterns string[] The patterns tracked by this occurrence.

-- A stateful representation of an occurrence of a pattern in a buffer.
---@class occurrence.Occurrence: occurrence.OccurrenceState
---@field buffer integer The buffer in which the occurrence was found.
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
---@return occurrence.Occurrence
function occurrence.new(buffer, text, opts)
  local self = setmetatable({ buffer = buffer or vim.api.nvim_get_current_buf() }, OCCURRENCE_META)
  Occurrence.set(self, text, opts)
  return self
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
-- If `direction` is set, a match directly at the cursor position will be ignored.
---@param opts? { direction?: 'forward' | 'backward', marked?: boolean, wrap?: boolean }
---@return occurrence.Range | nil
function Occurrence:match_cursor(opts)
  opts = vim.tbl_extend("force", { direction = nil, marked = false, wrap = false }, opts or {})
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  assert(#state.patterns > 0, "Occurrence has not been initialized with a pattern")
  assert(self.buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursor = Cursor.save() -- store cursor position before searching.

  local next_match = nil
  local prev_match = nil

  local bounds = opts.wrap and Range.of_buffer() or nil

  local flags = SearchFlags({ wrap = opts.wrap })

  if opts.direction == "forward" then
    next_match = closest(state, flags, cursor.location, bounds)
  elseif opts.direction == "backward" then
    prev_match = closest(state, flags({ backward = true }), cursor.location, bounds)
  else
    next_match = closest(state, flags({ cursor = true }), cursor.location, bounds)
    prev_match = closest(state, flags({ backward = true }), cursor.location, bounds)
  end

  -- If `marked` is `true`, keep searching until
  -- we find a marked occurrence in each direction.
  if opts.marked then
    local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
    if next_match and not extmarks:has(next_match) then
      local start = next_match
      repeat
        cursor:move(next_match.start)
        next_match = closest(state, flags, cursor.location, bounds)
      until not next_match or extmarks:has(next_match) or next_match == start
    end
    if prev_match and not extmarks:has(prev_match) then
      local start = prev_match
      repeat
        cursor:move(prev_match.start)
        prev_match = closest(state, flags({ backward = true }), cursor.location, bounds)
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
      local prev_dist =
        math.min(char_dist(cursor.location, prev_match.start), char_dist(cursor.location, prev_match.stop))
      local next_dist =
        math.min(char_dist(cursor.location, next_match.start), char_dist(cursor.location, next_match.stop))
      if opts.wrap and bounds then
        -- If wrapping is enabled, we need to consider the distance to the bounds.
        if opts.direction == "backward" then
          prev_dist =
            math.min(prev_dist, char_dist(cursor.location, bounds.start) + char_dist(bounds.stop, prev_match.stop))
          next_dist =
            math.min(next_dist, char_dist(cursor.location, bounds.stop) + char_dist(bounds.start, next_match.stop))
        else
          prev_dist =
            math.min(prev_dist, char_dist(cursor.location, bounds.stop) + char_dist(bounds.start, prev_match.start))
          next_dist =
            math.min(next_dist, char_dist(cursor.location, bounds.start) + char_dist(bounds.stop, next_match.start))
        end
      end

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
-- If no `range` is provided, the entire buffer will be marked.
---@param range? occurrence.Range
---@return boolean marked Whether occurrences were marked.
function Occurrence:mark(range)
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  local success = false
  for match in self:matches(range) do
    if extmarks:add(self.buffer, match) then
      success = true
    end
  end
  return success
end

-- Unmark the occurrences contained within the given `Range`.
-- If no `range` is provided, all occurrences will be unmarked.
---@param range? occurrence.Range
---@return boolean unmarked Whether occurrences were unmarked.
function Occurrence:unmark(range)
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  local success = false
  for match in self:matches(range) do
    if extmarks:del(self.buffer, match) then
      success = true
    end
  end
  return success
end

-- Whether or not the buffer contains at least one match for the occurrence.
function Occurrence:has_matches()
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  if #state.patterns == 0 then
    return false
  end
  for _, pattern in ipairs(state.patterns) do
    if vim.fn.search(pattern, "ncw") ~= 0 then
      return true
    end
  end
  return false
end

-- Get an iterator of matching occurrence ranges.
-- If `range` is provided, only yields the occurrences contained within the given `Range`.
---@param range? occurrence.Range
---@return fun(): occurrence.Range next_match
function Occurrence:matches(range)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  local start_location = range and range.start or Location.new(0, 0)
  local last_location = start_location

  ---@type occurrence.PatternMatchState[]
  local pattern_matchers = vim.iter(ipairs(state.patterns)):fold({}, function(acc, i, pattern)
    ---@class occurrence.PatternMatchState
    local match_state = {
      ---@type string
      pattern = pattern,
      ---@type occurrence.Location
      location = start_location,
      ---@type occurrence.Range | nil
      match = nil,
      ---@type occurrence.SearchFlags
      flags = { cursor = true },
    }

    function match_state.peek()
      local cursor = Cursor.save()
      cursor:move(match_state.location)
      match_state.match = search(match_state.pattern, match_state.flags)
      cursor:restore()
      if match_state.match and range and not range:contains(match_state.match) then
        match_state.match = nil
      end
      return match_state.match
    end

    function match_state.pop()
      if match_state.match then
        match_state.location = match_state.match.start
        -- Do not match at the cursor postiion again.
        match_state.flags.cursor = false
      end
    end

    table.insert(acc, match_state)
    return acc
  end)

  local function next_match()
    local next_best_match = nil
    for _, next_pattern_match in ipairs(pattern_matchers) do
      local match = next_pattern_match.peek()
      if match then
        if not next_best_match then
          next_best_match = match
        elseif char_dist(last_location, match.start) < char_dist(last_location, next_best_match.start) then
          next_best_match = match
        end
      end
    end
    if next_best_match then
      for _, next_pattern_match in ipairs(pattern_matchers) do
        if next_pattern_match.match == next_best_match then
          next_pattern_match.pop()
          break
        end
      end
      last_location = next_best_match.start

      return next_best_match
    end
    return nil
  end
  return next_match
end

-- Get an iterator of the marked occurrence ranges.
-- If the `range` option is provided, only yields the marked occurrences contained within the given `Range`.
-- If the `reverse` option is `true` (default is `false`), yields the marked occurrences in reverse order.
--
-- The iterator yields two `Range` values for each marked occurrence:
-- - The orginal range of the marked occurrence.
--   This can be used to unmark the occurrence, e.g., `occurrence:unmark(original_range)`.
-- - The current 'live' range of the marked occurrence.
--   This can be used to make edits to the buffer, e.g., with `vim.api.nvim_buf_set_text(...)`.
---@param opts? { range?: occurrence.Range, reverse?: boolean }
---@return fun(): occurrence.Range?, occurrence.Range? next_mark
function Occurrence:marks(opts)
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  ---@diagnostic disable-next-line: param-type-mismatch
  return extmarks:iter(self.buffer, opts)
end

-- Whether or not there is at least one marked occurrence in the buffer.
function Occurrence:has_marks()
  local extmarks = assert(EXTMARKS_CACHE[self], "Occurrence has not been initialized")
  return extmarks:has_any()
end

-- Set the text to search for.
-- If the `is_word` option is set, the text will only match when surrounded with word boundaries.
---@param text? string
---@param opts? { is_word: boolean }
function Occurrence:set(text, opts)
  -- (re-)initialize the internal state store for this Occurrence.
  local state = { patterns = {} }
  STATE_CACHE[self] = state

  -- Clear all extmarks and highlights.
  EXTMARKS_CACHE[self] = Extmarks.new()
  vim.api.nvim_buf_clear_namespace(self.buffer, NS, 0, -1)

  if text ~= nil then
    self:add(text, opts)
  end
end

-- Add an additional text pattern to search for.
-- If the `is_word` option is set, the text will only match when surrounded with word boundaries.
---@param text string
---@param opts? { is_word: boolean }
function Occurrence:add(text, opts)
  local state = assert(STATE_CACHE[self], "Occurrence has not been initialized")
  local escaped = text:gsub("\n", "\\n")
  local pattern = opts and opts.is_word and string.format([[\V\C\<%s\>]], escaped) or string.format([[\V\C%s]], escaped)
  table.insert(state.patterns, pattern)
end

return occurrence
