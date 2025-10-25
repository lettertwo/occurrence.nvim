local Cursor = require("occurrence.Cursor")
local Disposable = require("occurrence.Disposable")
local Extmarks = require("occurrence.Extmarks")
local Keymap = require("occurrence.Keymap")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")

local feedkeys = require("occurrence.feedkeys")
local log = require("occurrence.log")
local resolve_buffer = require("occurrence.resolve_buffer")

local function callable(fn)
  return type(fn) == "function" or (type(fn) == "table" and getmetatable(fn) and getmetatable(fn).__call)
end

---@alias occurrence.PatternType 'pattern' | 'selection' | 'word'

-- A map of Buffer ids to their Occurrence instances.
---@type table<integer, occurrence.Occurrence>
local OCCURRENCE_CACHE = {}

---@module 'occurrence.Occurrence'

-- Function to be used as a callback for an action.
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
-- If the function returns `false`, the occurrence will be disposed.
---@alias occurrence.ActionCallback fun(occurrence: occurrence.Occurrence, config: occurrence.Config): false?

-- An action that will exit operator_pending mode, set occurrences
-- of the current word and then re-enter operator-pending mode
-- with `:h opfunc`.
---@class (exact) occurrence.OperatorModifierConfig
---@field type "operator-modifier"
---@field mode "o"
---@field expr true
---@field plug? string
---@field desc? string
---@field callback? occurrence.ActionCallback

-- An action that will run and then activate occurrence mode keymaps,
-- if not already active.
---@class (exact) occurrence.OccurrenceModeConfig
---@field type "occurrence-mode"
---@field mode? "n" | "v" | ("n" | "v")[]
---@field plug? string
---@field desc? string
---@field callback? occurrence.ActionCallback

-- A descriptor for an action to be applied to occurrences.
---@alias occurrence.ActionConfig
---   | occurrence.OccurrenceModeConfig
---   | occurrence.OperatorModifierConfig
---   | { callback: occurrence.ActionCallback }

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

---@param state occurrence.Occurrence
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
    for _, pattern in ipairs(state.patterns) do
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

-- A stateful representation of an occurrence of a pattern in a buffer.
---@class occurrence.Occurrence: occurrence.Disposable
---@field buffer integer The buffer the occurrence is in.
---@field extmarks occurrence.Extmarks The extmarks used to highlight marked occurrences.
---@field keymap occurrence.Keymap The buffer-local keymap for this occurrence.
---@field patterns string[] The patterns used to search for occurrences.
local Occurrence = {}

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
  assert(#self.patterns > 0, "Occurrence has not been initialized with a pattern")
  assert(self.buffer == vim.api.nvim_get_current_buf(), "buffer not matching the current buffer not yet supported")
  local cursor = Cursor.save() -- store cursor position before searching.

  local next_match = nil
  local prev_match = nil

  local bounds = opts.wrap and Range.of_buffer() or nil

  local flags = SearchFlags({ wrap = opts.wrap })

  if opts.direction == "forward" then
    next_match = closest(self, flags, cursor.location, bounds)
  elseif opts.direction == "backward" then
    prev_match = closest(self, flags({ backward = true }), cursor.location, bounds)
  else
    next_match = closest(self, flags({ cursor = true }), cursor.location, bounds)
    prev_match = closest(self, flags({ backward = true }), cursor.location, bounds)
  end

  -- If `marked` is `true`, keep searching until
  -- we find a marked occurrence in each direction.
  if opts.marked then
    local extmarks = self.extmarks
    if next_match and not extmarks:has_mark(next_match) then
      local start = next_match
      repeat
        cursor:move(next_match.start)
        next_match = closest(self, flags, cursor.location, bounds)
      until not next_match or extmarks:has_mark(next_match) or next_match == start
    end
    if prev_match and not extmarks:has_mark(prev_match) then
      local start = prev_match
      repeat
        cursor:move(prev_match.start)
        prev_match = closest(self, flags({ backward = true }), cursor.location, bounds)
      until not prev_match or extmarks:has_mark(prev_match) or prev_match == start
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

---@class occurrence.Status
---@field current integer Current match index (1-based)
---@field total integer Total number of matches
---@field exact_match integer 1 if cursor is exactly on a match, 0 otherwise
---@field marked_only boolean Whether counting only marked occurrences

-- Get search count information similar `:h searchcount()`.
-- Returns the position of the cursor within matches and the total count.
-- If `marked` is `true`, only marked occurrences will be counted.
-- If `pos` is provided, it will be used as the cursor position instead of the actual cursor.
---@param opts? { marked?: boolean, pos?: occurrence.Location } Options for status
---@return occurrence.Status
function Occurrence:status(opts)
  opts = opts or {}
  local marked_only = opts.marked or false
  local pos = opts.pos or Location.of_cursor()

  local current = 0
  local total = 0
  local exact_match = 0
  local current_match = nil

  if not pos then
    return {
      current = 0,
      total = 0,
      exact_match = 0,
      marked_only = marked_only,
    }
  end

  if marked_only then
    -- Count marked occurrences
    for _, range in self.extmarks:iter_marks() do
      total = total + 1
      if range:contains(pos) then
        current = total
        exact_match = 1
        current_match = range
      elseif not current_match and range.start > pos then
        -- First match after cursor
        current = total
        current_match = range
      elseif not current_match then
        -- Before cursor, increment current
        current = total
      end
    end
  else
    -- Count all matches
    for range in self:matches() do
      total = total + 1
      if range:contains(pos) then
        current = total
        exact_match = 1
        current_match = range
      elseif not current_match and range.start > pos then
        -- First match after cursor
        current = total
        current_match = range
      elseif not current_match then
        -- Before cursor, increment current
        current = total
      end
    end
  end

  -- If we never found a match after cursor and there are matches, we're past the last match
  if total > 0 and current == 0 then
    current = total
  end

  return {
    current = current,
    total = total,
    exact_match = exact_match,
    marked_only = marked_only,
  }
end

-- Mark the occurrences contained within the given `Range`.
-- If no `range` is provided, the entire buffer will be marked.
---@param range? occurrence.Range
---@return boolean marked Whether occurrences were marked.
function Occurrence:mark(range)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  local extmarks = self.extmarks
  local success = false
  for match in self:matches(range) do
    if extmarks:mark(match) then
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
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  local success = false
  for match in self:matches(range) do
    if self.extmarks:unmark(match) then
      success = true
    end
  end
  return success
end

-- Whether or not the buffer contains at least one match for the occurrence.
---@param range? occurrence.Range
---@return boolean
function Occurrence:has_matches(range)
  if #self.patterns == 0 then
    return false
  end

  if range then
    return self:matches(range)() ~= nil
  end

  for _, pattern in ipairs(self.patterns) do
    if vim.fn.search(pattern, "ncw") ~= 0 then
      return true
    end
  end
  return false
end

-- Get an iterator of matching occurrence ranges.
-- If `range` is provided, only yields the occurrences contained within the given `Range`.
-- If `patterns` is provided, only yields occurrences matching these patterns.
---@param range? occurrence.Range
---@param patterns? string | string[]
---@return fun(): occurrence.Range next_match
function Occurrence:matches(range, patterns)
  local start_location = range and range.start or Location.new(0, 0)
  local last_location = start_location

  if patterns == nil then
    patterns = self.patterns
  elseif type(patterns) == "string" then
    patterns = { patterns }
  end

  ---@type occurrence.PatternMatchState[]
  local pattern_matchers = vim.iter(ipairs(patterns)):fold({}, function(acc, _, pattern)
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
        end
      end
      last_location = next_best_match.start

      return next_best_match
    end
    return nil
  end
  return next_match
end

-- Add an additional text pattern to search for.
-- If the pattern was already added, this is a no-op.
---@param text string
---@param pattern_type? occurrence.PatternType The type of occurrence matching to use. Default is 'pattern'.
function Occurrence:add_pattern(text, pattern_type)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  local pattern = text:gsub("\n", "\\n")
  if pattern_type == "selection" then
    pattern = string.format([[\V\C%s]], pattern)
  elseif pattern_type == "word" then
    pattern = string.format([[\V\C\<%s\>]], pattern)
  end

  for _, existing in ipairs(self.patterns) do
    if existing == pattern then
      return
    end
  end

  table.insert(self.patterns, pattern)
  for match in self:matches(nil, pattern) do
    self.extmarks:add(match)
  end
end

function Occurrence:clear()
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  self.extmarks:clear()
  self.patterns = {}
end

-- Apply the given `action` and `config` to this occurrence.
-- If `action` is a string, it will be resolved to an API action config.
-- If `action` is a table with a `callback` field, it will be treated as an action config:
--   - If `action.type == "occurrence-mode"`, `config:activate_occurrence_mode` will be called after the callback.
--   - If `action.type == "operator-modifier"`, `config:modify_operator` will be called after the callback.
-- Finally, if `action` is callable, it will be called directly.
-- In all cases, the action callback will receive this `Occurrence` and the `config` as arguments,
-- and if it returns `false`, any followup behavior (as with "occurrence-mode" and "operator-modifier" types)
-- will be skipped, and this occurrence will be disposed.
---@param action occurrence.Api | occurrence.ActionConfig | occurrence.ActionCallback
---@param config occurrence.Config
function Occurrence:apply(action, config)
  local callback = nil
  local action_config = nil

  if type(action) == "string" then
    action_config = require("occurrence.api")[action]
  elseif callable(action) then
    callback = action
  elseif type(action) == "table" then
    action_config = action
  end

  if action_config and (action_config.type or action_config.callback) then
    if action_config.type == "occurrence-mode" then
      ---@cast action_config occurrence.OccurrenceModeConfig
      local ok, result = pcall(action_config.callback, self, config)
      if not ok or result == false then
        log.debug("Occurrence mode action cancelled")
        self:dispose()
      elseif not self:has_matches() then
        log.warn("No matches found for pattern(s):", table.concat(self.patterns, ", "), "skipping activation")
        self:dispose()
      elseif not self.keymap:is_active() then
        log.debug("Activating occurrence mode keymaps for buffer", self.buffer)
        config:activate_occurrence_mode(self)
      end
      return
    elseif action_config.type == "operator-modifier" then
      ---@cast action_config occurrence.OperatorModifierConfig
      if self.keymap:is_active() then
        log.debug("Operator modifier skipped; occurrence mode is active!")
        return
      end

      local ok, result = pcall(action_config.callback, self, config)
      if not ok or result == false then
        log.debug("Operator modifier cancelled")
        self:dispose()
        return
      end

      config:modify_operator(self)
      return
    else
      callback = action_config.callback
    end
  end

  if callback and callable(callback) then
    local result = callback(self, config)
    if result == false then
      self:dispose()
      return
    end
    return result
  else
    error("Invalid action: " .. vim.inspect(action))
  end
end

-- Apply an operator to marked occurrences.
--
-- The `operator_name` may be a built-in operator (e.g., `"change"`, `"delete"`, etc),
-- or a key for an operator as defined in the `config.operators` table
-- (e.g., `"c"`, `"d"`, or any custom operator).
--
-- If `motion` is a `Range`, it will be used to create the visual selection.
-- If `motion` is a string like `"$"`,`"ip"`, etc., it will be used to create a motion via `:h feedkeys()`.
--
-- If `motion_type` is provided and `motion` is a `Range`, it will be used to determine
-- how the visual selection is created:
--   - `'char'` (default) for character-wise selection
--   - `'line'` for line-wise selection
--   - `'block'` for block-wise selection
-- Note that If `apply_operator` is called while in a visual mode,
-- the current visual selection will be used instead of any `motion`.
--
-- If no occurrences are marked after the operation, the occurrence will be disposed.
---@param operator_name occurrence.BuiltinOperator | string
---@param motion? string | occurrence.Range The range of motion (e.g. "aw", "$", etc), or a defined range. If `nil`, the full buffer range will be used.
---@param motion_type? 'char' | 'line' | 'block' The type of motion, if `motion` is a `Range`. Defaults to 'char'.
function Occurrence:apply_operator(operator_name, motion, motion_type)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  local config = require("occurrence").resolve_config()
  local operator_config = config:get_operator_config(operator_name)
  if type(operator_config) == "table" then
    -- In visual mode, use the current visual selection.
    if vim.fn.mode():find("[vV]") ~= nil then
      motion = nil
    elseif type(motion) ~= "string" then
      -- Create a visual selection for the operator.
      motion = motion or Range.of_buffer()
      Cursor.move(motion.start)
      if motion_type == "line" then
        feedkeys.change_mode("V", { silent = true })
      elseif motion_type == "block" then
        feedkeys.change_mode("", { silent = true })
      else
        feedkeys.change_mode("v", { silent = true })
      end
      Cursor.move(motion.stop)
    end
    require("occurrence.Operator").create_opfunc("v", self, operator_config, operator_name, vim.v.count, vim.v.register)
    if type(motion) == "string" then
      -- Apply opfunc to the motion.
      feedkeys("g@" .. motion, { noremap = true })
    else
      -- Apply opfunc to the visual selection.
      feedkeys("g@", { noremap = true })
    end
  else
    log.error("Invalid operator:", operator_name)
  end
end

-- Get or create an Occurrence for the given buffer and text.
-- If no `buffer` is provided, the current buffer will be used.
-- If a `text` pattern is provided, it will be added to the active occurrence patterns.
-- Optional `pattern_type` is the same as for `Occurrence:add`.
---@param buffer? integer
---@param text? string
---@param pattern_type? occurrence.PatternType
---@return occurrence.Occurrence
local function get_or_create_occurrence(buffer, text, pattern_type)
  buffer = resolve_buffer(buffer, true)
  local self = OCCURRENCE_CACHE[buffer]
  if not self then
    self = {} ---@diagnostic disable-line: missing-fields
    local state = {
      extmarks = Extmarks.new(buffer),
      keymap = Keymap.new(buffer),
      patterns = {},
    }
    local disposable = Disposable.new()
    disposable:add(state.extmarks)
    disposable:add(state.keymap)
    setmetatable(self, {
      __index = function(tbl, key)
        if rawget(tbl, key) ~= nil then
          return rawget(tbl, key)
        elseif key == "buffer" then
          return buffer
        elseif state[key] ~= nil then
          return state[key]
        elseif Occurrence[key] ~= nil then
          return Occurrence[key]
        elseif disposable[key] ~= nil then
          return disposable[key]
        end
      end,
    })
    self:add(function()
      OCCURRENCE_CACHE[buffer] = nil
    end)
    OCCURRENCE_CACHE[buffer] = self
  end
  if text then
    self:add_pattern(text, pattern_type)
  end
  return self
end

-- Delete the Occurrence for the given buffer, disposing of its resources.
-- If no `buffer` is provided, the current buffer will be used.
---@param buffer? integer
---@return boolean deleted Whether an Occurrence was deleted.
local function delete_occurrence(buffer)
  buffer = resolve_buffer(buffer, true)
  local self = OCCURRENCE_CACHE[buffer]
  if self then
    self:dispose()
    OCCURRENCE_CACHE[buffer] = nil
    return true
  end
  return false
end

-- Autocmd to cleanup occurrences when a buffer is deleted.
vim.api.nvim_create_autocmd({ "BufDelete" }, {
  group = vim.api.nvim_create_augroup("OccurrenceCleanup", { clear = true }),
  callback = function(args)
    delete_occurrence(args.buf)
  end,
})

return {
  get = get_or_create_occurrence,
  del = delete_occurrence,
}
