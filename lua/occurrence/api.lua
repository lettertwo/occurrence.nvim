local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")

local log = require("occurrence.log")

---@module 'occurrence.api'

---@type occurrence.PresetConfig
local find_word = {
  desc = "Find occurrences of word",
  type = "preset",
  callback = function(occurrence)
    local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
    if word == "" then
      log.warn("No word under cursor")
      return
    end
    occurrence:add_pattern(word, "word")
  end,
}

---@type occurrence.PresetConfig
local mark_word = {
  desc = "Mark occurrences of word",
  type = "preset",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    find_word.callback(occurrence)
    -- mark all occurrences of the newest pattern
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for range in occurrence:matches(nil, pattern) do
        occurrence:mark(range)
      end
    end
  end,
}

---@type occurrence.PresetConfig
local find_selection = {
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
    occurrence:add_pattern(text, "selection")
    -- Clear visual selection
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  end,
}

---@type occurrence.PresetConfig
local mark_selection = {
  desc = "Mark occurrences of selection",
  type = "preset",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    find_selection.callback(occurrence)
    -- mark all occurrences of the newest pattern
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for range in occurrence:matches(nil, pattern) do
        occurrence:mark(range)
      end
    end
  end,
}

---@type occurrence.PresetConfig
local find_last_search = {
  desc = "Find occurrences of last search",
  type = "preset",
  callback = function(occurrence)
    local pattern = vim.fn.getreg("/")

    if pattern == "" then
      log.warn("No search pattern available")
      return
    end

    occurrence:add_pattern(pattern)
  end,
}

---@type occurrence.PresetConfig
local mark_last_search = {
  desc = "Mark occurrences of last search",
  type = "preset",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    find_last_search.callback(occurrence)
    -- mark all occurrences of the newest pattern
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for range in occurrence:matches(nil, pattern) do
        occurrence:mark(range)
      end
    end
  end,
}

-- Find all occurrences using the current search pattern if available,
-- otherwise use the word under the cursor.
---@type occurrence.PresetConfig
local find_search_or_word = {
  desc = "Find occurrences of search or word",
  type = "preset",
  callback = function(occurrence)
    if vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= "" then
      local result = find_last_search.callback(occurrence)
      if result ~= false then
        -- clear the hlsearch as we're going to to replace it with occurrence highlights.
        vim.cmd.nohlsearch()
      end
      return result
    end
    return find_word.callback(occurrence)
  end,
}

---@type occurrence.PresetConfig
local mark_search_or_word = {
  desc = "Mark occurrences of search or word",
  type = "preset",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    find_search_or_word.callback(occurrence)
    -- mark all occurrences of the newest pattern
    if occurrence.patterns ~= nil and #occurrence.patterns > pattern_count then
      local pattern = occurrence.patterns[#occurrence.patterns]
      for range in occurrence:matches(nil, pattern) do
        occurrence:mark(range)
      end
    end
  end,
}

---@type occurrence.PresetConfig
local goto_next = {
  desc = "Next occurrence",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "forward", wrap = true })
  end,
}

---@type occurrence.PresetConfig
local goto_previous = {
  desc = "Previous occurrence",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "backward", wrap = true })
  end,
}

---@type occurrence.PresetConfig
local goto_next_mark = {
  desc = "Next marked occurrence",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
  end,
}

---@type occurrence.PresetConfig
local goto_previous_mark = {
  desc = "Previous marked occurrence",
  type = "preset",
  callback = function(occurrence)
    occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
  end,
}

-- Add a mark and highlight for the current match of the given occurrence.
---@type occurrence.PresetConfig
local mark = {
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
  desc = "Unmark occurrence",
  type = "preset",
  callback = function(occurrence)
    local range = occurrence:match_cursor()
    if range then
      occurrence:unmark(range)
    end
  end,
}

---@type occurrence.PresetConfig
local toggle_mark = {
  desc = "Toggle occurrence mark",
  type = "preset",
  callback = function(occurrence)
    local range = occurrence:match_cursor()
    if range then
      if not occurrence:mark(range) then
        occurrence:unmark(range)
      end
    end
  end,
}

---@type occurrence.PresetConfig
local mark_word_or_toggle_mark = {
  desc = "Add/Toggle occurrence mark",
  type = "preset",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    if pattern_count == 0 then
      return mark_word.callback(occurrence)
    end
    local cursor = Cursor.save()
    local range = occurrence:match_cursor()
    if range and range:contains(cursor.location) then
      return toggle_mark.callback(occurrence)
    else
      cursor:restore()
      return mark_word.callback(occurrence)
    end
  end,
}

-- Add marks and highlights for all matches of the given occurrence.
---@type occurrence.PresetConfig
local mark_all = {
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

-- Toggle marks and highlights for matches of the given occurrence within the current selection.
---@type occurrence.PresetConfig
local toggle_marks_in_selection = {
  desc = "Toggle occurrence marks",
  type = "preset",
  callback = function(occurrence)
    local selection_range = Range:of_selection()
    if selection_range then
      for range in occurrence:matches(selection_range) do
        if not occurrence:mark(range) then
          occurrence:unmark(range)
        end
      end
    end
  end,
}

---@type occurrence.PresetConfig
local toggle_selection = {
  type = "preset",
  desc = "Add/Toggle occurrence marks",
  callback = function(occurrence)
    local pattern_count = occurrence.patterns and #occurrence.patterns or 0
    if pattern_count == 0 then
      return mark_selection.callback(occurrence)
    end
    local selection_range = Range.of_selection()
    if selection_range and occurrence:has_matches(selection_range) then
      return toggle_marks_in_selection.callback(occurrence)
    else
      return mark_selection.callback(occurrence)
    end
  end,
}

local deactivate = {
  desc = "Clear occurrence",
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
  desc = "Modify operator to act on marked occurrences",
  type = "operator-modifier",
  callback = function(occurrence)
    mark_word.callback(occurrence)
    if not occurrence.extmarks:has_any_marks() then
      return false
    end
  end,
}

---@enum (key) occurrence.Api
local api = {
  find_word = find_word,
  find_selection = find_selection,
  find_last_search = find_last_search,
  find_search_or_word = find_search_or_word,
  goto_next = goto_next,
  goto_previous = goto_previous,
  goto_next_mark = goto_next_mark,
  goto_previous_mark = goto_previous_mark,
  mark = mark,
  unmark = unmark,
  toggle_mark = toggle_mark,
  mark_word_or_toggle_mark = mark_word_or_toggle_mark,
  mark_all = mark_all,
  unmark_all = unmark_all,
  mark_in_selection = mark_in_selection,
  unmark_in_selection = unmark_in_selection,
  toggle_marks_in_selection = toggle_marks_in_selection,
  toggle_selection = toggle_selection,
  mark_word = mark_word,
  mark_selection = mark_selection,
  mark_last_search = mark_last_search,
  mark_search_or_word = mark_search_or_word,
  modify_operator = modify_operator,
  deactivate = deactivate,
}

return api
