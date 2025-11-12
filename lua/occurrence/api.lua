local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")

local log = require("occurrence.log")

---@module 'occurrence.api'

-- Modify a pending operator to act on occurrences of the word
-- under the cursor. Only useful in operator-pending mode
-- (e.g., `c`, `d`, etc.)
--
-- Once a pending operator is modified, the operator will act
-- on occurrences within the range specified by the subsequent motion.
--
-- Note that this action does not activate occurrence mode,
-- and it does not have any effect when occurrence mode is active,
-- as operators already act on occurrences in that mode.
---@type occurrence.OperatorModifierConfig
local modify_operator = {
  mode = "o",
  expr = true,
  plug = "<Plug>(OccurrenceModifyOperator)",
  desc = "Occurrences",
  type = "operator-modifier",
  callback = function(occurrence, ...)
    if not occurrence:has_matches() then
      occurrence:of_word(true)
    end
    if not occurrence.extmarks:has_any_marks() then
      return false
    end
  end,
}

-- Mark one or more occurrences and activate occurrence mode.
--
-- If occurrence already has matches, mark matches based on:
-- - In visual mode, if matches exist in the range of the visual
--   selection, mark those matches.
-- - Otherwise, if a match exists at the cursor, mark that match.
--
-- If no occurrence match exists to satisfy the above, add a new pattern based on:
--   - In visual mode, mark occurrences of the visual selection.
--   - If `:h hlsearch` is active, mark occurrences of the search pattern.
--   - Otherwise, mark occurrences of the word under the cursor.
---@type occurrence.OccurrenceModeConfig
local mark = {
  mode = { "n", "v" },
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceMark)",
  desc = "Mark occurrence",
  callback = function(occurrence)
    local visual = vim.fn.mode():match("[vV]") ~= nil
    local hlsearch = vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= ""

    if occurrence:has_matches() then
      if visual then
        local selection_range = Range.of_selection()
        if selection_range and occurrence:has_matches(selection_range) then
          for range in occurrence:matches(selection_range) do
            occurrence:mark(range)
          end
        end
      else
        local cursor = Cursor.save()
        local range = occurrence:match_cursor()
        if range and range:contains(cursor.location) then
          occurrence:mark(range)
        else
          cursor:restore()
          occurrence:of_word(true)
        end
      end
    elseif visual then
      occurrence:of_selection(true)
    elseif hlsearch then
      occurrence:of_pattern(true)
    else
      occurrence:of_word(true)
    end
  end,
}

-- Unmark one or more occurrences.
--
-- If occurrence has matches, unmark matches based on:
-- - In visual mode, unmark matches in the range of the visual selection.
-- - Otherwise, if a match exists at the cursor, unmark that match.
--
-- If no match exists to satisfy the above, does nothing.
---@type occurrence.OccurrenceModeConfig
local unmark = {
  mode = { "n", "v" },
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceUnmark)",
  desc = "Unmark occurrence",
  callback = function(occurrence)
    local visual = vim.fn.mode():match("[vV]") ~= nil
    if occurrence:has_matches() then
      if visual then
        local selection_range = Range:of_selection()
        if selection_range then
          for range in occurrence:matches(selection_range) do
            occurrence:unmark(range)
          end
        end
      else
        local range = occurrence:match_cursor()
        if range then
          occurrence:unmark(range)
        end
      end
    end
  end,
}

-- Mark or unmark one (or more) occurrence(s) and activate occurrence mode.
--
-- If occurrence already has matches, toggle matches based on:
-- - In visual mode, if matches exist in the range of the visual
--   selection, toggle marks on those matches.
-- - Otherwise, if a match exists at the cursor, toggle that mark.
--
-- If no occurrence match exists to satisfy the above, add a new pattern based on:
--   - In visual mode, mark the closest occurrence of the visual selection.
--   - If `:h hlsearch` is active, mark the closest occurrence of the search pattern.
--   - Otherwise, mark the closest occurrence of the word under the cursor.
---@type occurrence.OccurrenceModeConfig
local toggle = {
  mode = { "n", "v" },
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceToggle)",
  desc = "Add/Toggle occurrence mark(s)",
  callback = function(occurrence, ...)
    local visual = vim.fn.mode():match("[vV]") ~= nil
    local hlsearch = vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= ""

    if occurrence:has_matches() then
      if visual then
        local selection_range = Range.of_selection()
        if selection_range and occurrence:has_matches(selection_range) then
          for range in occurrence:matches(selection_range) do
            if not occurrence:mark(range) then
              occurrence:unmark(range)
            end
          end
        end
      else
        local cursor = Cursor.save()
        local range = occurrence:match_cursor()
        if range and range:contains(cursor.location) then
          if not occurrence:mark(range) then
            occurrence:unmark(range)
          end
        else
          cursor:restore()
          if occurrence:of_word() then
            occurrence:mark(occurrence:match_cursor())
            cursor:restore()
          end
        end
      end
    elseif visual then
      if occurrence:of_selection() then
        occurrence:mark(occurrence:match_cursor())
      end
    elseif hlsearch then
      if occurrence:of_pattern() then
        occurrence:mark(occurrence:match_cursor())
      end
    elseif occurrence:of_word() then
      occurrence:mark(occurrence:match_cursor())
    end
  end,
}

-- Move to the next marked occurrence and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the next marked occurrence.
---@type occurrence.OccurrenceModeConfig
local next = {
  mode = "n",
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceNext)",
  desc = "Next marked occurrence",
  callback = function(occurrence, ...)
    if not occurrence:has_matches() then
      mark.callback(occurrence, ...)
    end
    occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
  end,
}

-- Move to the previous marked occurrence and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the previous marked occurrence.
---@type occurrence.OccurrenceModeConfig
local previous = {
  mode = "n",
  type = "occurrence-mode",
  plug = "<Plug>(OccurrencePrevious)",
  desc = "Previous marked occurrence",
  callback = function(occurrence, ...)
    if not occurrence:has_matches() then
      mark.callback(occurrence, ...)
    end
    occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
  end,
}

-- Move to the next occurrence match, whether marked or unmarked,
-- and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the next occurrence match.
---@type occurrence.OccurrenceModeConfig
local match_next = {
  mode = "n",
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceMatchNext)",
  desc = "Next occurrence match",
  callback = function(occurrence, ...)
    if not occurrence:has_matches() then
      mark.callback(occurrence, ...)
    end
    occurrence:match_cursor({ direction = "forward", wrap = true })
  end,
}

-- Move to the previous occurrence match, whether marked or unmarked,
-- and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the previous occurrence match.
---@type occurrence.OccurrenceModeConfig
local match_previous = {
  mode = "n",
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceMatchPrevious)",
  desc = "Previous occurrence match",
  callback = function(occurrence, ...)
    if not occurrence:has_matches() then
      mark.callback(occurrence, ...)
    end
    occurrence:match_cursor({ direction = "backward", wrap = true })
  end,
}

-- Clear all marks and patterns, and deactivate occurrence mode.
---@type occurrence.OccurrenceModeConfig
local deactivate = {
  mode = "n",
  desc = "Clear occurrence",
  plug = "<Plug>(OccurrenceDeactivate)",
  type = "occurrence-mode",
  callback = function(occurrence)
    if occurrence.extmarks:has_any_marks() then
      log.debug("Occurrence still has marks during deactivate")
    end
    occurrence:dispose()
    return false
  end,
}

---@enum (key) occurrence.KeymapAction
local api = {
  modify_operator = modify_operator,
  mark = mark,
  unmark = unmark,
  toggle = toggle,
  next = next,
  previous = previous,
  match_next = match_next,
  match_previous = match_previous,
  deactivate = deactivate,
}

return api
