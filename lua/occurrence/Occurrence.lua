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

-- Function to be used as a callback for a keymap
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
-- If the function returns `false`, the occurrence will be disposed.
---@alias occurrence.KeymapCallback fun(occurrence: occurrence.Occurrence, args?: occurrence.SubcommandArgs): false?

-- A configuration for an occurrence mode keymap.
-- A keymap defined this way will be buffer-local and
-- active only when occurrence mode is active.
---@class (exact) occurrence.KeymapConfig
-- The callback function to invoke when the keymap is triggered.
---@field callback occurrence.KeymapCallback
-- The mode(s) in which the keymap is active.
-- Note that, regardless of these modes, the keymap will
-- only be active when occurrence mode is active.
---@field mode? "n" | "v" | ("n" | "v")[]
-- An optional description for the keymap.
-- Similar to the `desc` field in `:h vim.keymap.set` options.
---@field desc? string

-- A configuration for a global keymap that will exit operator_pending mode,
-- set occurrences of the current word and then re-enter operator-pending mode
-- with `:h opfunc`.
---@class (exact) occurrence.OperatorModifierConfig: occurrence.KeymapConfig
---@field type "operator-modifier"
---@field mode "o"
---@field expr true
---@field plug string

-- A configuration for a global keymap that will run and then
-- activate occurrence mode keymaps, if not already active.
---@class (exact) occurrence.OccurrenceModeConfig: occurrence.KeymapConfig
---@field type "occurrence-mode"
---@field plug string

---@class (exact) occurrence.OperatorCurrent
---@field id number The extmark id for the occurrence
---@field index number 1-based index of the occurrence
---@field range occurrence.Range The range of the occurrence
---@field text string[] The text of the occurrence as a list of lines

---@class (exact) occurrence.OperatorContext: { [string]: any }
---@field occurrence occurrence.Occurrence
---@field marks [number, occurrence.Range][]
---@field mode 'n' | 'v' | 'o' The mode from which the operator is being triggered.
---@field register? occurrence.Register The register being used for the operation.

-- A function to be used as an operator on marked occurrences.
-- The function will be called for each marked occurrence with the following arguments:
--  - `current`: a table representing the occurrence currently being processed:
--    - `id`: the extmark id for the occurrence
--    - `index`: the index of the occurrence among all marked occurrences to be processed
--    - `range`: a table representing the range of the occurrence (see `occurrence.OccurrenceRange`)
--    - `text`: the text of the occurrence as a list of lines
--  - `ctx`: a table containing context for the operation:
--    - `occurrence`: the active occurrence state for the buffer (see `occurrence.Occurrence`)
--    - `marks`: a list of all marked occurrences as `[id, range]` tuples
--    - `mode`: the mode from which the operator is being triggered ('n', 'v', or 'o')
--    - `register`: the register being used for the operation (see `occurrence.Register`)
-- The `ctx` may also be used to store state between calls for each occurrence.
--
-- The function should return either:
--   - `string | string[]` to replace the occurrence text
--   - `nil | true` to leave the occurrence unchanged and proceed to the next occurrence
--   - `false` to cancel the operation on this and all remaining occurrences
--
--  If the return value is truthy (not `nil | false`), the original text
--  of the occurrence will be yanked to the register specified in `ctx.register`.
--  To prevent this, set `ctx.register` to `nil`.
---@alias occurrence.OperatorFn fun(mark: occurrence.OperatorCurrent, ctx: occurrence.OperatorContext): string | string[] | boolean | nil

-- A configuration for a keymap that will run an operation
-- on occurrences either as part of modifying a pending operator,
-- or when occurrence mode is active.
---@class (exact) occurrence.OperatorConfig
-- The operatation to perform on each marked occcurence. Either:
--   - a key sequence (e.g., `"gU"`) to be applied to the visual selection of each marked occurrence,
--   - or a function that will be called for each marked occurrence.
---@field operator string | occurrence.OperatorFn
-- The mode(s) in which the operator keymap is active.
-- Note that:
--  - if "n" or "v" are included, the keymap will
--    only be active when occurrence mode is active.
--  - if "o" is included, a pending operator matching this keymap
--    can be modified to operate on occurrences.
-- Defaults to `{ "n", "v", "o" }`.
---@field mode? "n" | "v" | "o" | ("n" | "v" | "o")[]
-- An optional description for the keymap.
-- Similar to the `desc` field in `:h vim.keymap.set` options.
---@field desc? string

-- Internal descriptor for actions
---@alias occurrence.ApiConfig
---   | occurrence.OccurrenceModeConfig
---   | occurrence.OperatorModifierConfig
---   | occurrence.OperatorConfig

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
    for _, range in self.extmarks:iter() do
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
  extmarks:update_current()
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
  self.extmarks:update_current()
  return success
end

-- Mark all occurrences in the buffer.
---@return boolean marked Whether occurrences were marked.
function Occurrence:mark_all()
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  local success = false
  for match in self:matches() do
    if self.extmarks:mark(match) then
      success = true
    end
  end
  self.extmarks:update_current()
  return success
end

-- Unmark all occurrences in the buffer.
---@return boolean unmarked Whether occurrences were unmarked.
function Occurrence:unmark_all()
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  local success = false
  for match in self:matches() do
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
-- If `start` is provided instead of `range`, yields occurrences starting from the given `Location`.
-- If `count` is provided, yields at most `count` occurrences.
-- If `patterns` is provided, only yields occurrences matching these patterns.
---@param range? occurrence.Range
---@param count? number
---@param patterns? string | string[]
---@return fun(): occurrence.Range? next_match
---@overload fun(self: occurrence.Occurrence, start: occurrence.Location, count?: number, patterns?: string | string[]): fun(): occurrence.Range? next_match
function Occurrence:matches(range, count, patterns)
  local start_location = nil
  if type(range) == "table" then
    if range.start and range.start.col and range.start.line then
      start_location = range.start
    else
      ---@cast range -occurrence.Range
      if range.line and range.col then
        ---@cast range +occurrence.Location
        start_location = range
        range = nil
      end
    end
  end
  start_location = start_location or Location.new(0, 0)
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

  local total = 0
  local function next_match()
    if count and count > 0 and total >= count then
      return nil
    end
    total = total + 1
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

-- Get an iterator of marked occurrence ranges.
-- If a `range` is provided, only yields the marks contained within the given `Range`.
---@param range? occurrence.Range
---@return fun(): occurrence.Range? next_mark
function Occurrence:marks(range)
  local next_extmark = self.extmarks:iter(range)
  local function next_mark()
    local _, mark = next_extmark()
    return mark
  end
  return next_mark
end

-- Add an additional text pattern to search for.
-- If the pattern was already added, this is a no-op.
---@param text string
---@param pattern_type? occurrence.PatternType The type of occurrence matching to use. Default is 'pattern'.
---@return string pattern The added pattern
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
      return pattern
    end
  end

  table.insert(self.patterns, pattern)
  for match in self:matches(nil, nil, pattern) do
    self.extmarks:add(match)
  end
  return pattern
end

-- Add a pattern for the current visual selection.
-- If `mark` is `true`, all occurrences of the selection will be marked.
-- Returns `true` if a new pattern was added, `false` otherwise.
-- If no visual selection exists, or if the visual selection is empty,
-- logs a warning and returns `false`.
--
-- Clears the visual selection after adding the pattern.
--
---@param mark? boolean Whether to mark all occurrences of the selection.
---@param range? occurrence.Range The range of the visual selection. If not provided, uses the current visual selection.
---@return boolean success Whether a new pattern was added.
function Occurrence:of_selection(mark, range)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")

  range = range or Range.of_selection()
  if not range then
    log.warn("No visual selection")
    return false
  end

  local text = table.concat(
    vim.api.nvim_buf_get_text(self.buffer, range.start.line, range.start.col, range.stop.line, range.stop.col, {}),
    "\n"
  )
  if text == "" then
    log.warn("Empty visual selection")
    return false
  end

  local pattern = self:add_pattern(text, "selection")

  -- Clear visual selection
  feedkeys.change_mode("n", { noflush = true, silent = true })

  if mark then
    -- mark all occurrences of the newest pattern
    for match in self:matches(nil, nil, pattern) do
      self:mark(match)
    end
  end

  return true
end

-- Add the last search pattern.
-- If `mark` is `true`, all occurrences of the pattern will be marked.
-- Returns `true` if a new pattern was added, `false` otherwise.
-- If no last search pattern exists, logs a warning and returns `false`.
--
-- Clears the search highlight after adding the pattern.
--
---@param mark? boolean Whether to mark all occurrences of the pattern.
---@param search_pattern? string The search pattern to add. If not provided, uses the last search pattern.
---@return boolean success Whether a new pattern was added.
function Occurrence:of_pattern(mark, search_pattern)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")

  search_pattern = search_pattern or vim.fn.getreg("/")

  if search_pattern == "" then
    log.warn("No search pattern available")
    return false
  end

  local pattern = self:add_pattern(search_pattern, "pattern")

  -- Clear search highlight
  vim.cmd.nohlsearch()

  if mark then
    -- mark all occurrences of the newest pattern
    for match in self:matches(nil, nil, pattern) do
      self:mark(match)
    end
  end

  return true
end

-- Add a pattern for the word under the cursor.
-- If `mark` is `true`, all occurrences of the word will be marked.
-- Returns `true` if a new pattern was added, `false` otherwise.
-- If no word exists under the cursor, logs a warning and returns `false`.
---@param mark? boolean Whether to mark all occurrences of the word.
---@param word? string The word to add. If not provided, uses the word under the cursor.
---@return boolean success Whether a new pattern was added.
function Occurrence:of_word(mark, word)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")

  word = word or vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter

  if word == "" then
    log.warn("No word under cursor")
    return false
  end

  local pattern = self:add_pattern(word, "word")

  if mark then
    -- mark all occurrences of the newest pattern
    for match in self:matches(nil, nil, pattern) do
      self:mark(match)
    end
  end

  return true
end

-- Whether occurrence mode is currently active for this occurrence.
---@return boolean
function Occurrence:is_active()
  return not self:is_disposed() and self.keymap:is_active()
end

function Occurrence:clear()
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")
  self.extmarks:clear()
  self.patterns = {}
end

---@class occurrence.ModifyOperatorOptions
---@field operator? string The operator to modify (e.g. "d", "y", etc). If `nil`, modifies the pending operator.
---@field count? number The count to use for the operator
---@field register? string The register to use for the operator

---@param options? occurrence.ModifyOperatorOptions
---@param config? occurrence.Config
function Occurrence:modify_operator(options, config)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")

  local count = (options and options.count) or vim.v.count
  local register = (options and options.register) or vim.v.register
  local operator_key = (options and options.operator) or vim.v.operator

  config = require("occurrence").resolve_config(config)
  local operator_config = config:get_operator_config(operator_key, "o")

  if not operator_config then
    log.warn(string.format("Operator '%s' is not supported", operator_key))
    -- If we have failed to modify the pending operator
    -- to use the occurrence, we should dispose of it.
    self:dispose()
    return
  end

  -- cancel the pending op.
  feedkeys.change_mode("n", { force = true, noflush = true, silent = true })

  -- Schedule sending `g@` to trigger custom opfunc on the next frame.
  -- This is async to allow the first mode change event to cycle.
  -- If we did this synchronously, there would be no opportunity for
  -- other plugins (e.g. which-key) to react to the modified operator mode change.
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.schedule(function()
    log.debug("Activating operator-pending keymaps for buffer", self.buffer)

    local autocmd_id = nil
    autocmd_id = vim.api.nvim_create_autocmd("ModeChanged", {
      pattern = "*:n",
      callback = function(e)
        log.debug("ModeChanged event:", e.match)
        vim.schedule(function()
          -- if we are still in normal mode, then we assume
          -- it is safe to dispose of the occurrence.
          if vim.api.nvim_get_mode().mode == "n" then
            log.debug("Operator-pending mode exited, clearing occurrence for buffer", self.buffer)
            self:dispose()
            pcall(vim.api.nvim_del_autocmd, autocmd_id)
          end
        end)
      end,
    })
    -- Create the opfunc that will be called with the motion type
    require("occurrence.Operator").create_opfunc(self, operator_config.operator, {
      mode = "o",
      count = count,
      register = register,
    })
    -- re-enter operator-pending mode
    feedkeys.change_mode("o", { silent = true })
  end)
end

---@param config? occurrence.Config
function Occurrence:activate_occurrence_mode(config)
  config = require("occurrence").resolve_config(config)
  if config.default_keymaps then
    -- Disable the default operator-pending mapping.
    -- Note that this isn't strictly necessary, since the modify operator
    -- command is a no-op when occurrence mode is active,
    -- but it gives some descriptive feedback to the user to update the binding.
    self.keymap:set("o", "o", "<Nop>")
  end

  -- Set up buffer-local keymaps for occurrence mode actions
  for action_key in pairs(config.keymaps) do
    local action_config = config:get_keymap_config(action_key)
    if action_config then
      local desc = action_config.desc
      local mode = action_config.mode or { "n", "v" }

      if action_config.plug then
        -- Use <Plug> mapping if defined
        self.keymap:set(mode, action_key, action_config.plug, { desc = desc })
      elseif action_config.callback then
        -- Fall back to direct callback
        self.keymap:set(mode, action_key, function()
          self:apply(action_config, nil, config)
        end, { desc = desc })
      else
        -- No plug or callback defined
        log.warn_once(string.format("Action config for '%s' has no plug or callback defined", action_key))
      end
    end
  end

  -- Set up buffer-local keymaps for operators
  for operator_key in pairs(config.operators) do
    local operator_config = config:get_operator_config(operator_key)
    if operator_config then
      local desc = operator_config.desc or ("'" .. operator_key .. "' on marked occurrences")
      local mode = operator_config.mode
      if mode ~= "o" then
        if type(mode) == "table" then
          mode = vim.tbl_filter(function(m)
            return m ~= "o"
          end, mode)
        end
        self.keymap:set(mode or { "n", "v" }, operator_key, function()
          require("occurrence.Operator").create_opfunc(self, operator_config.operator, {
            mode = vim.fn.mode():match("[vV]") and "v" or "n",
            count = vim.v.count,
            register = vim.v.register,
          })
          -- send g@ to trigger custom opfunc
          return "g@"
        end, { desc = desc, expr = true })
      end
    else
      log.warn_once(string.format("Operator '%s' is not supported", operator_key))
    end
  end

  if callable(config.on_activate) then
    config.on_activate(function(mode, lhs, rhs, opts)
      self.keymap:set(mode, lhs, rhs, opts)
    end)
  end
end

-- Apply the given `action` and `config` to this occurrence.
-- If `action` is a string, it will be resolved to a keymap config.
-- If `action` is a table with a `callback` field, it will be treated as a keymap config:
--   - If `action.type == "occurrence-mode"`, `self:activate_occurrence_mode` will be called after the callback.
--   - If `action.type == "operator-modifier"`, `self:modify_operator` will be called after the callback.
--   - If `action.type == "operator"`, the callback will be called directly with operator context.
-- Finally, if `action` is callable, it will be called directly.
-- In all cases, the action callback will receive this `Occurrence` and the `config` as arguments,
-- and if it returns `false`, any followup behavior (as with "occurrence-mode" and "operator-modifier" types)
-- will be skipped, and this occurrence will be disposed.
---@param action occurrence.KeymapAction | occurrence.ApiConfig | occurrence.KeymapConfig | occurrence.KeymapCallback
---@param args? occurrence.SubcommandArgs
---@param config? occurrence.Config
function Occurrence:apply(action, args, config)
  local callback = nil
  local action_config = nil

  if type(action) == "string" then
    action_config = require("occurrence.api")[action]
  elseif callable(action) then
    callback = action
  elseif type(action) == "table" then
    action_config = action
  end

  if action_config and (action_config.type or action_config.callback or action_config.operator) then
    if action_config.type == "occurrence-mode" then
      ---@cast action_config occurrence.OccurrenceModeConfig
      local ok, result = pcall(action_config.callback, self, args)
      if not ok or result == false then
        log.debug("Occurrence mode action cancelled")
        self:dispose()
      elseif not self:has_matches() then
        log.warn("No matches found for pattern(s):", table.concat(self.patterns, ", "), "skipping activation")
        self:dispose()
      elseif not self.keymap:is_active() then
        log.debug("Activating occurrence mode keymaps for buffer", self.buffer)
        self:activate_occurrence_mode(config)
      end
      return
    elseif action_config.type == "operator-modifier" then
      ---@cast action_config occurrence.OperatorModifierConfig
      if self.keymap:is_active() then
        log.debug("Operator modifier skipped; occurrence mode is active!")
        return
      end

      if not vim.api.nvim_get_mode().mode:match("o") and (not args or not args[1]) then
        log.error("modify_operator can only be called in operator-pending mode")
        return
      end

      local ok, result = pcall(action_config.callback, self, args)
      if not ok or result == false then
        log.debug("Operator modifier cancelled")
        self:dispose()
        return
      end
      self:modify_operator(args and {
        count = args.count,
        operator = args[1],
        register = args[2],
      } or nil, config)
      return
    elseif action_config.operator ~= nil then
      self:apply_operator(action_config.operator, args and {
        count = args.count,
        motion = args.range,
        motion_type = args.range and "line" or nil,
        register = args[1],
      } or nil, config)
      return
    else
      callback = action_config.callback
    end
  end

  if callback and callable(callback) then
    local result = callback(self, args)
    if result == false then
      log.debug("Occurrence mode action cancelled")
      self:dispose()
      return
    end
    return result
  else
    error("Invalid action: " .. vim.inspect(action))
  end
end

---@class occurrence.ApplyOperatorOptions
---@field mode? 'n' | 'v' | 'o' The mode in which to apply the operator
---@field count? number The count to use for the operator
---@field register? string The register to use for the operator
---@field motion? string | occurrence.Range The range of motion (e.g. "aw", "$", etc), or a defined range. If `nil`, the full buffer range will be used.
---@field motion_type? 'char' | 'line' | 'block' The type of motion, if `motion` is a `Range`. Defaults to 'char'.

-- Apply an operator to marked occurrences.
--
-- The `operator` may be:
--   - the name of a built-in or configured operator (e.g., `"change"`, `"delete"`, etc),
--   - or a key sequence (e.g., `"gU"`) to be applied to the visual selection of each marked occurrence,
--   - or a function that will be called for each marked occurrence.
--
-- The `:h operatorfunc` will be defined as a function that applies the operator
-- to each marked occurrence in the range defined by a `motion` (optionally limited to `count` occurrences).
--
-- If `apply_operator` is called while in a visual mode,
-- the current visual selection will be used instead of any `motion`.
--
-- Otherwise, the `motion` may be defined as:
--   - a `Range` defining the range of motion,
--   - or a string defining a motion (e.g., `"$"`, `"ip"`, etc).
--   - or `nil` to enter operator-pending mode and await a motion input.
--
-- If `motion_type` is provided and `motion` is a `Range`, it will be used to determine
-- how the range of selection should be interpreted:
--   - `'char'` (default) for character-wise selection
--   - `'line'` for line-wise selection
--   - `'block'` for block-wise selection
--
-- If `count` is provided, it will limit the number of occurrences to which the operator is applied
-- to the smaller of `count` or the number of marked occurrences in the motion range.
--
-- If no occurrences are marked after the operation, the occurrence will be disposed.
--
---@param operator string | occurrence.OperatorFn
---@param options? occurrence.ApplyOperatorOptions
---@param config? occurrence.Config
function Occurrence:apply_operator(operator, options, config)
  assert(not self:is_disposed(), "Cannot use a disposed Occurrence")

  local visual = vim.fn.mode():match("[vV]") ~= nil
  local mode = options and options.mode or (visual and "v" or "n")
  local register = options and options.register or vim.v.register
  -- We only want to consume the count if we are modifying an operator
  -- or if it is explicitly provided. Otherwise, we assume `vim.v.count`
  -- is meant for the motion that follows.
  local count = options and options.count or (mode == "o" and vim.v.count or 0)
  -- Resolve the motion (if not in visual mode)
  local motion = (mode ~= "v" and options and options.motion) or nil

  -- Force visual mode if motion is a Range
  if motion ~= nil and type(motion) ~= "string" then
    mode = "v"
  end

  -- Try to resolve a string operator to an operator config
  -- before treating it as a key sequence.
  if type(operator) == "string" then
    config = require("occurrence").resolve_config(config)
    local operator_config = config:get_operator_config(operator)
    if operator_config and operator_config.operator then
      operator = operator_config.operator
    end
  end

  -- Create the opfunc that will be called with the motion type
  require("occurrence.Operator").create_opfunc(self, operator, {
    mode = mode,
    count = count,
    register = register,
  })

  if type(motion) == "string" then
    -- Motion is a string: execute opfunc with motion
    feedkeys("g@" .. motion, { noremap = true })
  elseif motion ~= nil then
    local motion_type = options and options.motion_type or nil
    -- Motion is a Range: create visual selection and execute opfunc
    motion_type = motion_type or "char"
    Cursor.move(motion.start)
    if motion_type == "line" then
      feedkeys.change_mode("V", { silent = true })
    elseif motion_type == "block" then
      feedkeys.change_mode("^V", { silent = true })
    else
      feedkeys.change_mode("v", { silent = true })
    end
    Cursor.move(motion.stop)
    -- Apply opfunc to the visually selected range.
    feedkeys("g@", { noremap = true })
  elseif visual then
    -- Apply opfunc to the visual selection.
    feedkeys("g@", { noremap = true })
  else
    -- enter operator-pending mode
    feedkeys.change_mode("o", { silent = true })
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

    -- Set up autocmd to update current occurrence highlight on cursor movement
    local augroup = vim.api.nvim_create_augroup("OccurrenceCurrent_" .. buffer, { clear = true })
    local autocmd_id = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = augroup,
      buffer = buffer,
      callback = function()
        if not self:is_disposed() then
          self.extmarks:update_current()
        end
      end,
    })

    disposable:add(function()
      pcall(vim.api.nvim_del_autocmd, autocmd_id)
      pcall(vim.api.nvim_del_augroup_by_id, augroup)
    end)

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

-- Whether an Occurrence exists for the given buffer.
-- If no `buffer` is provided, the current buffer will be used.
---@param buffer? integer
---@return boolean exists
local function has_occurrence(buffer)
  buffer = resolve_buffer(buffer, true)
  return OCCURRENCE_CACHE[buffer] ~= nil
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
    log.debug("Buffer deleted, cleaning up occurrence for buffer", args.buf)
    delete_occurrence(args.buf)
  end,
})

return {
  get = get_or_create_occurrence,
  has = has_occurrence,
  del = delete_occurrence,
}
