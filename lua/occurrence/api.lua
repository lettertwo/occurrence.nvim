local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")

local feedkeys = require("occurrence.feedkeys")
local log = require("occurrence.log")

---@module 'occurrence.api'

---@type occurrence.PresetConfig
local word = {
  mode = "n",
  plug = "<Plug>(OccurrenceWord)",
  desc = "Find occurrences of word",
  type = "preset",
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

---@type occurrence.PresetConfig
local selection = {
  mode = "v",
  plug = "<Plug>(OccurrenceSelection)",
  desc = "Find occurrences of selection",
  type = "preset",
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

---@type occurrence.PresetConfig
local pattern = {
  mode = "n",
  plug = "<Plug>(OccurrencePattern)",
  desc = "Find occurrences of search pattern",
  type = "preset",
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

-- Find occurrences using the current selection if active,
-- or the current search pattern if available,
-- or the word under the cursor.
---@type occurrence.PresetConfig
local current = {
  plug = "<Plug>(OccurrenceCurrent)",
  desc = "Find occurrences",
  type = "preset",
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

---@type occurrence.PresetConfig
local match_next = {
  mode = "n",
  plug = "<Plug>(OccurrenceMatchNext)",
  desc = "Next occurrence match",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "forward", wrap = true })
  end,
}

---@type occurrence.PresetConfig
local match_previous = {
  mode = "n",
  plug = "<Plug>(OccurrenceMatchPrevious)",
  desc = "Previous occurrence match",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "backward", wrap = true })
  end,
}

---@type occurrence.PresetConfig
local next = {
  mode = "n",
  plug = "<Plug>(OccurrenceNext)",
  desc = "Next marked occurrence",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
  end,
}

---@type occurrence.PresetConfig
local previous = {
  mode = "n",
  plug = "<Plug>(OccurrencePrevious)",
  desc = "Previous marked occurrence",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
  end,
}

-- Add a mark and highlight for the current match of the given occurrence.
---@type occurrence.PresetConfig
local mark = {
  mode = "n",
  plug = "<Plug>(OccurrenceMark)",
  desc = "Mark occurrence",
  type = "preset",
  callback = function(occurrence)
    local range = occurrence:match_cursor()
    if range then
      occurrence:mark(range)
    end
  end,
}

-- Remove a mark and highlight for the current match of the given occurrence.
---@type occurrence.PresetConfig
local unmark = {
  mode = "n",
  plug = "<Plug>(OccurrenceUnmark)",
  desc = "Unmark occurrence",
  type = "preset",
  callback = function(occurrence)
    local range = occurrence:match_cursor()
    if range then
      occurrence:unmark(range)
    end
  end,
}

-- Add marks and highlights for all matches of the given occurrence.
---@type occurrence.PresetConfig
local mark_all = {
  mode = "n",
  desc = "Mark occurrences",
  type = "preset",
  callback = function(occurrence)
    for range in occurrence:matches() do
      occurrence:mark(range)
    end
  end,
}

-- Clear all marks and highlights for the given occurrence.
---@type occurrence.PresetConfig
local unmark_all = {
  mode = "n",
  desc = "Unmark occurrences",
  type = "preset",
  callback = function(occurrence)
    for range in occurrence.extmarks:iter_marks() do
      occurrence:unmark(range)
    end
  end,
}

-- Add marks and highlights for matches of the given occurrence within the current selection.
---@type occurrence.PresetConfig
local mark_in_selection = {
  mode = "v",
  desc = "Mark occurences",
  type = "preset",
  callback = function(occurrence)
    local selection_range = Range:of_selection()
    if selection_range then
      for range in occurrence:matches(selection_range) do
        occurrence:mark(range)
      end
    end
  end,
}

-- Clear marks and highlights for matches of the given occurrence within the current selection.
---@type occurrence.PresetConfig
local unmark_in_selection = {
  mode = "v",
  desc = "Unmark occurrences",
  type = "preset",
  callback = function(occurrence)
    local selection_range = Range:of_selection()
    if selection_range then
      for range in occurrence.extmarks:iter_marks({ range = selection_range }) do
        occurrence:unmark(range)
      end
    end
  end,
}

---@type occurrence.PresetConfig
local toggle = {
  mode = { "n", "v" },
  plug = "<Plug>(OccurrenceToggle)",
  desc = "Add/Toggle occurrence mark(s)",
  type = "preset",
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

local deactivate = {
  mode = "n",
  desc = "Clear occurrence",
  plug = "<Plug>(OccurrenceDeactivate)",
  type = "preset",
  callback = function(occurrence)
    if occurrence.extmarks:has_any() then
      log.debug("Occurrence still has marks during deactivate")
    end
    occurrence:dispose()
    return false
  end,
}

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
