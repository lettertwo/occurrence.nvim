local Keymap = require("occurrency.Keymap")
local Action = require("occurrency.Action")
local Range = require("occurrency.Range")
local log = require("occurrency.log")

-- A map of Buffer ids to their active keymaps.
---@type table<integer, Keymap>
local KEYMAP_CACHE = {}

local function opfunc(callback)
  -- FIXME: This is a hack around pending support for lua functions in this position.
  -- See https://github.com/neovim/neovim/pull/20187
  _G.OccurrencyOpfunc = function(...)
    callback(...)
    -- FIXME: This opfunc attempts to clean up after itself,
    -- but if the opeation is cancelled, the opfunc won't be called..
    _G.OccurrencyOpfunc = nil
  end
  vim.api.nvim_set_option("operatorfunc", "v:lua.OccurrencyOpfunc")
  return "g@"
end

local M = {}

-- Find all occurrences of the word under the cursor in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
M.find_cursor_word = Action:new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
  assert(word ~= "", "no word under cursor")
  occurrence:set(word, { is_word = true })
end)

-- Find all occurrences of the visually selected text in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
M.find_visual_subword = Action:new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  local text = table.concat(vim.api.nvim_buf_get_text(0, pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3], {}))
  assert(text ~= "", "no text selected")
  occurrence:set(text)
end)

-- Go to the next occurrence.
M.goto_next = Action:new(function(occurrence)
  occurrence:match({ nearest = true, move = true })
end)

-- Go to the previous occurrence.
M.goto_previous = Action:new(function(occurrence)
  occurrence:match({ reverse = true, nearest = true, move = true })
end)

-- Go to the next mark.
M.goto_next_mark = Action:new(function(occurrence)
  occurrence:match({ nearest = true, move = true, marked = true })
end)

-- Go to the previous mark.
M.goto_previous_mark = Action:new(function(occurrence)
  occurrence:match({ reverse = true, nearest = true, move = true, marked = true })
end)

-- Add a mark and highlight for the current match of the given occurrence.
M.mark = Action:new(function(occurrence)
  occurrence:match_cursor()
  if occurrence.range then
    occurrence:mark()
  end
end)

-- Remove a mark and highlight for the current match of the given occurrence.
M.unmark = Action:new(function(occurrence)
  occurrence:match_cursor()
  if occurrence.range then
    occurrence:unmark()
  end
end)

-- Toggle a mark and highlight for the current match of the given occurrence.
M.toggle_mark = Action:new(function(occurrence)
  occurrence:match_cursor()
  if occurrence.range then
    if not occurrence:mark() then
      occurrence:unmark()
    end
  end
end)

-- Add marks and highlights for matches of the given occurrence within the current selection.
M.mark_selection = Action:new(function(occurrence)
  local start = occurrence.range
  if start then
    local selection_range = Range:of_selection()
    if selection_range then
      repeat
        if selection_range:contains(occurrence.range) then
          occurrence:mark()
        end
        occurrence:match()
      until occurrence.range == start
    end
  end
end)

-- Clear marks and highlights for matches of the given occurrence within the current selection.
M.unmark_selection = Action:new(function(occurrence)
  local start = occurrence.range
  if start then
    local selection_range = Range:of_selection()
    if selection_range then
      repeat
        if selection_range:contains(occurrence.range) then
          occurrence:unmark()
        end
        occurrence:match()
      until occurrence.range == start
    end
  end
end)

-- Toggle marks and highlights for matches of the given occurrence within the current selection.
M.toggle_mark_selection = Action:new(function(occurrence)
  local start = occurrence.range
  if start then
    local selection_range = Range:of_selection()
    if selection_range then
      repeat
        if selection_range:contains(occurrence.range) then
          if not occurrence:mark() then
            occurrence:unmark()
          end
        end
        occurrence:match()
      until occurrence.range == start
    end
  end
end)

-- Add marks and highlights for all matches of the given occurrence.
M.mark_all = Action:new(function(occurrence)
  local start = occurrence.range
  if start then
    repeat
      occurrence:mark()
      occurrence:match()
    until occurrence.range == start
  end
end)

-- Clear all marks and highlights for the given occcurrence.
M.unmark_all = Action:new(function(occurrence)
  local start = occurrence.range
  if start then
    repeat
      occurrence:unmark()
      occurrence:match()
    until occurrence.range == start
  end
end)

-- Change all marked occurrences.
M.change = Action:new(function(occurrence)
  return opfunc(function(type)
    log.debug("change", type, occurrence.pattern)
  end)
end)

-- Delete all marked occurrences.
M.delete = Action:new(function(occurrence, type)
  return opfunc(function(type)
    log.debug("delete", type, occurrence.pattern)
  end)
end)

-- Creates an action to activate keybindings for the given configuration and mode.
---@param mode OccurrencyKeymapMode
---@param config OccurrencyConfig
M.activate_keymap = Action:new(function(occurrence, mode, config)
  Keymap.validate_mode(mode)
  if not occurrence.range then
    log.debug("No matches found for pattern:", occurrence.pattern, "skipping activation")
    return
  end
  log.debug("Activating keybindings for buffer", occurrence.buffer, "and mode", mode)
  if KEYMAP_CACHE[occurrence.buffer] then
    log.error("Keymap is already active!")
    KEYMAP_CACHE[occurrence.buffer]:reset()
  end
  local keymap = Keymap:new(occurrence.buffer)
  KEYMAP_CACHE[occurrence.buffer] = keymap

  if mode == "n" then
    keymap:n("n", M.goto_next_mark:with(occurrence), "Next marked occurrence")
    keymap:n("N", M.goto_previous_mark:with(occurrence), "Previous marked occurrence")
    keymap:n("gn", M.goto_next:with(occurrence), "Next occurrence")
    keymap:n("gN", M.goto_previous:with(occurrence), "Previous occurrence")
    keymap:n("go", M.toggle_mark:with(occurrence), "Toggle occurrence mark")
    keymap:n("ga", M.mark:with(occurrence), "Mark occurrence")
    keymap:n("gx", M.unmark:with(occurrence), "Unmark occurrence")

    -- Use visual/select to narrow an active occurrence.
    keymap:x("go", M.toggle_mark_selection:with(occurrence), "Toggle occurrence marks")
    keymap:x("ga", M.mark_selection:with(occurrence), "Mark occurrences")
    keymap:x("gx", M.unmark_selection:with(occurrence), "Unmark occurrences")

    -- Deactivate occurrence operator.
    keymap:n("<Esc>", (M.unmark_all + M.deactivate_keymap):with(occurrence), "Clear marks and deactivate keywithings")
  elseif mode == "x" then
    -- Deactivate occurrence operator.
    keymap:n("<Esc>", (M.unmark_all + M.deactivate_keymap):with(occurrence), "Clear marks and deactivate keywithings")
  elseif mode == "o" then
    -- Deactivate occurrence operator.
    keymap:o("<Esc>", (M.unmark_all + M.deactivate_keymap):with(occurrence), "Clear marks and deactivate keywithings")
  end
end)

-- Deactivate the keymap for the given occurrence.
M.deactivate_keymap = Action:new(function(occurrence)
  local keymap = KEYMAP_CACHE[occurrence.buffer]
  if keymap then
    keymap:reset()
    KEYMAP_CACHE[occurrence.buffer] = nil
    log.debug("Deactivated keybindings for buffer", occurrence.buffer)
  end
end)

return M
