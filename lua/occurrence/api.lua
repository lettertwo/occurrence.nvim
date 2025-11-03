local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")

local feedkeys = require("occurrence.feedkeys")
local log = require("occurrence.log")

---@module 'occurrence.api'

-- Find occurrences of the word under the cursor, mark all matches,
-- and activate occurrence mode
---@type occurrence.OccurrenceModeConfig
local word = {
  mode = "n",
  plug = "<Plug>(OccurrenceWord)",
  desc = "Find occurrences of word",
  type = "occurrence-mode",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
    if word == "" then
      log.warn("No word under cursor")
      return
    end
    -- mark all occurrences of the newest pattern
    occurrence:add_pattern(word, "word")
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for range in occurrence:matches(nil, pattern) do
        occurrence:mark(range)
      end
    end
  end,
}

-- Find occurrences of the current visual selection, mark all
-- matches, and activate occurrence mode
---@type occurrence.OccurrenceModeConfig
local selection = {
  mode = "v",
  plug = "<Plug>(OccurrenceSelection)",
  desc = "Find occurrences of selection",
  type = "occurrence-mode",
  callback = function(occurrence)
    local range = Range.of_selection()
    assert(range, "no visual selection")
    local text = table.concat(
      vim.api.nvim_buf_get_text(0, range.start.line, range.start.col, range.stop.line, range.stop.col, {}),
      "\n"
    )
    if text == "" then
      log.warn("Empty visual selection")
      return
    end
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    -- Clear visual selection
    feedkeys.change_mode("n", { noflush = true, silent = true })
    -- mark all occurrences of the newest pattern
    occurrence:add_pattern(text, "selection")
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for match in occurrence:matches(nil, pattern) do
        occurrence:mark(match)
      end
    end
  end,
}

-- Find occurrences of the last search pattern, mark all matches,
-- and activate occurrence mode
---@type occurrence.OccurrenceModeConfig
local pattern = {
  mode = "n",
  plug = "<Plug>(OccurrencePattern)",
  desc = "Find occurrences of search pattern",
  type = "occurrence-mode",
  callback = function(occurrence)
    local search_pattern = vim.fn.getreg("/")

    if search_pattern == "" then
      log.warn("No search pattern available")
      return
    end

    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    -- Clear search highlight
    vim.cmd.nohlsearch()
    -- mark all occurrences of the newest pattern
    occurrence:add_pattern(search_pattern)
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for range in occurrence:matches(nil, pattern) do
        occurrence:mark(range)
      end
    end
  end,
}

-- Smart entry action that adapts to the current context. In
-- visual mode: acts like `selection`. Otherwise, if `:h hlsearch`
-- is active: acts like `pattern`. Otherwise: acts like `word`.
-- Marks all matches and activates occurrence mode
---@type occurrence.OccurrenceModeConfig
local current = {
  plug = "<Plug>(OccurrenceCurrent)",
  desc = "Find occurrences",
  type = "occurrence-mode",
  callback = function(occurrence, ...)
    if vim.fn.mode():match("[vV]") then
      return selection.callback(occurrence, ...)
    elseif vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= "" then
      return pattern.callback(occurrence, ...)
    else
      return word.callback(occurrence, ...)
    end
  end,
}

-- Move to the next occurrence match, whether marked or unmarked
---@type occurrence.OccurrenceModeConfig
local match_next = {
  mode = "n",
  plug = "<Plug>(OccurrenceMatchNext)",
  desc = "Next occurrence match",
  type = "occurrence-mode",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "forward", wrap = true })
  end,
}

-- Move to the previous occurrence match, whether marked or unmarked
---@type occurrence.OccurrenceModeConfig
local match_previous = {
  mode = "n",
  plug = "<Plug>(OccurrenceMatchPrevious)",
  desc = "Previous occurrence match",
  type = "occurrence-mode",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "backward", wrap = true })
  end,
}

-- Move to the next marked occurrence
---@type occurrence.OccurrenceModeConfig
local next = {
  mode = "n",
  plug = "<Plug>(OccurrenceNext)",
  desc = "Next marked occurrence",
  type = "occurrence-mode",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
  end,
}

-- Move to the previous marked occurrence
---@type occurrence.OccurrenceModeConfig
local previous = {
  mode = "n",
  plug = "<Plug>(OccurrencePrevious)",
  desc = "Previous marked occurrence",
  type = "occurrence-mode",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
  end,
}

-- Mark the occurrence match nearest to the cursor
---@type occurrence.OccurrenceModeConfig
local mark = {
  mode = "n",
  plug = "<Plug>(OccurrenceMark)",
  desc = "Mark occurrence",
  type = "occurrence-mode",
  callback = function(occurrence)
    local range = occurrence:match_cursor()
    if range then
      occurrence:mark(range)
    end
  end,
}

-- Unmark the occurrence match nearest to the cursor
---@type occurrence.OccurrenceModeConfig
local unmark = {
  mode = "n",
  plug = "<Plug>(OccurrenceUnmark)",
  desc = "Unmark occurrence",
  type = "occurrence-mode",
  callback = function(occurrence)
    local range = occurrence:match_cursor()
    if range then
      occurrence:unmark(range)
    end
  end,
}

-- Mark all occurrence matches in the buffer
---@type occurrence.OccurrenceModeConfig
local mark_all = {
  mode = "n",
  desc = "Mark occurrences",
  type = "occurrence-mode",
  callback = function(occurrence)
    for range in occurrence:matches() do
      occurrence:mark(range)
    end
  end,
}

-- Unmark all occurrence matches in the buffer
---@type occurrence.OccurrenceModeConfig
local unmark_all = {
  mode = "n",
  desc = "Unmark occurrences",
  type = "occurrence-mode",
  callback = function(occurrence)
    for range in occurrence.extmarks:iter_marks() do
      occurrence:unmark(range)
    end
  end,
}

-- Mark all occurrence matches in the current visual selection
---@type occurrence.OccurrenceModeConfig
local mark_in_selection = {
  mode = "v",
  desc = "Mark occurences",
  type = "occurrence-mode",
  callback = function(occurrence)
    local selection_range = Range:of_selection()
    if selection_range then
      for range in occurrence:matches(selection_range) do
        occurrence:mark(range)
      end
    end
  end,
}

-- Unmark all occurrence matches in the current visual selection
---@type occurrence.OccurrenceModeConfig
local unmark_in_selection = {
  mode = "v",
  desc = "Unmark occurrences",
  type = "occurrence-mode",
  callback = function(occurrence)
    local selection_range = Range:of_selection()
    if selection_range then
      for range in occurrence.extmarks:iter_marks({ range = selection_range }) do
        occurrence:unmark(range)
      end
    end
  end,
}

-- Smart toggle action that activates occurrence mode or toggles
-- marks. In normal mode: If no patterns exist, acts like `word`
-- to start occurrence mode. Otherwise, toggles the mark on the
-- match under the cursor, or adds a new word pattern if not on a
-- match. In visual mode: If no patterns exist, acts like
-- `selection` to start occurrence mode. Otherwise, toggles marks
-- on all matches within the selection, or adds a new selection
-- pattern if no matches.
---@type occurrence.OccurrenceModeConfig
local toggle = {
  mode = { "n", "v" },
  plug = "<Plug>(OccurrenceToggle)",
  desc = "Add/Toggle occurrence mark(s)",
  type = "occurrence-mode",
  callback = function(occurrence, ...)
    if vim.fn.mode():match("[vV]") then
      local pattern_count = occurrence.patterns and #occurrence.patterns or 0
      if pattern_count == 0 then
        return selection.callback(occurrence, ...)
      end
      local selection_range = Range.of_selection()
      if selection_range and occurrence:has_matches(selection_range) then
        for range in occurrence:matches(selection_range) do
          if not occurrence:mark(range) then
            occurrence:unmark(range)
          end
        end
      else
        return selection.callback(occurrence, ...)
      end
    else
      local pattern_count = occurrence.patterns and #occurrence.patterns or 0
      if pattern_count == 0 then
        return word.callback(occurrence, ...)
      end
      local cursor = Cursor.save()
      local range = occurrence:match_cursor()
      if range and range:contains(cursor.location) then
        if not occurrence:mark(range) then
          occurrence:unmark(range)
        end
      else
        cursor:restore()
        return word.callback(occurrence, ...)
      end
    end
  end,
}

-- Clear all marks and patterns, and deactivate occurrence mode
---@type occurrence.OccurrenceModeConfig
local deactivate = {
  mode = "n",
  desc = "Clear occurrence",
  plug = "<Plug>(OccurrenceDeactivate)",
  type = "occurrence-mode",
  callback = function(occurrence)
    if occurrence.extmarks:has_any() then
      log.debug("Occurrence still has marks during deactivate")
    end
    occurrence:dispose()
    return false
  end,
}

-- Modify a pending operator to act on occurrences of the word
-- under the cursor. Used in operator-pending mode (e.g., `coo`
-- changes word occurrences, `doo` deletes them)
---@type occurrence.OperatorModifierConfig
local modify_operator = {
  mode = "o",
  expr = true,
  plug = "<Plug>(OccurrenceModifyOperator)",
  desc = "Occurrences",
  type = "operator-modifier",
  callback = function(occurrence, ...)
    word.callback(occurrence, ...)
    if not occurrence.extmarks:has_any_marks() then
      return false
    end
  end,
}

---@enum (key) occurrence.Api
local api = {
  word = word,
  selection = selection,
  pattern = pattern,
  current = current,

  next = next,
  previous = previous,
  match_next = match_next,
  match_previous = match_previous,

  mark = mark,
  unmark = unmark,

  mark_all = mark_all,
  unmark_all = unmark_all,

  mark_in_selection = mark_in_selection,
  unmark_in_selection = unmark_in_selection,

  toggle = toggle,

  modify_operator = modify_operator,
  deactivate = deactivate,
}

return api
