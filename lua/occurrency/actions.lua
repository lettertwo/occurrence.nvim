local Keymap = require("occurrency.Keymap")
local Action = require("occurrency.Action")
local Range = require("occurrency.Range")
local log = require("occurrency.log")

-- A map of Buffer ids to their active keymaps.
---@type table<integer, Keymap>
local KEYMAP_CACHE = {}

local function opfunc(callback)
  return function()
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
end

---@param mode string
local function setmode(mode)
  if mode == vim.api.nvim_get_mode().mode then
    return true
  end
  if mode == "n" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  else
    error("Unsupported mode: " .. mode)
  end
  return mode == vim.api.nvim_get_mode().mode
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
  setmode("n")
end)

-- Go to the next occurrence.
M.goto_next = Action:new(function(occurrence)
  occurrence:match_cursor({ direction = "forward", wrap = true })
end)

-- Go to the previous occurrence.
M.goto_previous = Action:new(function(occurrence)
  occurrence:match_cursor({ direction = "backward", wrap = true })
end)

-- Go to the next mark.
M.goto_next_mark = Action:new(function(occurrence)
  occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
end)

-- Go to the previous mark.
M.goto_previous_mark = Action:new(function(occurrence)
  occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
end)

-- Add a mark and highlight for the current match of the given occurrence.
M.mark = Action:new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    occurrence:mark(range)
  end
end)

-- Remove a mark and highlight for the current match of the given occurrence.
M.unmark = Action:new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    occurrence:unmark(range)
  end
end)

-- Toggle a mark and highlight for the current match of the given occurrence.
M.toggle_mark = Action:new(function(occurrence)
  local range = occurrence:match_cursor()
  log("toggle_mark", range)
  if range then
    if not occurrence:mark(range) then
      occurrence:unmark(range)
    end
  end
end)

-- Add marks and highlights for matches of the given occurrence within the current selection.
M.mark_selection = Action:new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:matches(selection_range) do
      occurrence:mark(range)
    end
  end
end)

-- Clear marks and highlights for matches of the given occurrence within the current selection.
M.unmark_selection = Action:new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:marks(selection_range) do
      occurrence:unmark(range)
    end
  end
end)

-- Toggle marks and highlights for matches of the given occurrence within the current selection.
M.toggle_mark_selection = Action:new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:matches(selection_range) do
      if not occurrence:mark(range) then
        occurrence:unmark(range)
      end
    end
  end
end)

-- Add marks and highlights for all matches of the given occurrence.
M.mark_all = Action:new(function(occurrence)
  for range in occurrence:matches() do
    occurrence:mark(range)
  end
end)

-- Clear all marks and highlights for the given occcurrence.
M.unmark_all = Action:new(function(occurrence)
  for range in occurrence:marks() do
    occurrence:unmark(range)
  end
end)

-- Change all marked occurrences.
---@param occurrence Occurrence
---@param selection? Range
M.change_marked = Action:new(function(occurrence, selection)
  for mark, range in occurrence:marks(selection) do
    log.debug("change_marked", occurrence.pattern, range)
  end
end)

M.change_selection = Action:new(function(occurrence)
  M.change_marked(occurrence, Range:of_selection())
end)

M.change_motion = Action:new(function(occurrence)
  M.change_marked(occurrence, Range:of_motion())
end)

-- Delete all marked occurrences.
---@param occurrence Occurrence
---@param selection? Range
M.delete_marked = Action:new(function(occurrence, selection)
  for mark, range in occurrence:marks(selection) do
    occurrence:unmark(mark)
    local start_line, start_col, stop_line, stop_col = unpack(range) ---@diagnostic disable-line: deprecated
    vim.api.nvim_buf_set_text(0, start_line, start_col, stop_line, stop_col, {})
  end
end)

M.delete_selection = Action:new(function(occurrence)
  M.delete_marked(occurrence, Range:of_selection())
  setmode("n")
end)

M.delete_motion = Action:new(function(occurrence)
  -- TODO: offset cursor position to account for deleted text...
  M.delete_marked(occurrence, Range:of_motion())
end)

-- Activate keybindings for the given configuration.
-- If an operator action is given, the action will be executed in operator-pending mode.
---@param config OccurrencyConfig
---@param operator? OccurrencyAction
M.activate = Action:new(function(occurrence, config, operator)
  if not occurrence:has_matches() then
    log.debug("No matches found for pattern:", occurrence.pattern, "skipping activation")
    return
  end
  log.debug("Activating keybindings for buffer", occurrence.buffer)
  if KEYMAP_CACHE[occurrence.buffer] then
    log.error("Keymap is already active!")
    KEYMAP_CACHE[occurrence.buffer]:reset()
  end
  local keymap = Keymap:new(occurrence.buffer)
  KEYMAP_CACHE[occurrence.buffer] = keymap

  -- Cancel the pending occurrence operation.
  keymap:n("<Esc>", (M.unmark_all + M.deactivate):with(occurrence), "Clear occurrence")

  if operator ~= nil then
    return opfunc(operator:with(occurrence))()
  else
    -- Navigate between occurrence matches
    keymap:n("n", M.goto_next_mark:with(occurrence), "Next marked occurrence")
    keymap:n("N", M.goto_previous_mark:with(occurrence), "Previous marked occurrence")
    keymap:n("gn", M.goto_next:with(occurrence), "Next occurrence")
    keymap:n("gN", M.goto_previous:with(occurrence), "Previous occurrence")

    -- Manage occurrence marks.
    keymap:n("go", M.toggle_mark:with(occurrence), "Toggle occurrence mark")
    keymap:n("ga", M.mark:with(occurrence), "Mark occurrence")
    keymap:n("gx", M.unmark:with(occurrence), "Unmark occurrence")

    -- Use visual/select to narrow occurrence matches.
    keymap:x("go", M.toggle_mark_selection:with(occurrence), "Toggle occurrence marks")
    keymap:x("ga", M.mark_selection:with(occurrence), "Mark occurrences")
    keymap:x("gx", M.unmark_selection:with(occurrence), "Unmark occurrences")

    -- Delete marked occurrences.
    -- TODO: add shortcuts like "dd", "dp", etc.
    keymap:n("d", opfunc(M.delete_motion:with(occurrence)), { expr = true, desc = "Delete marked occurrences" })
    keymap:x("d", (M.delete_selection):with(occurrence), "Delete marked occurrences")
  end
end)

-- Deactivate the keymap for the given occurrence.
M.deactivate = Action:new(function(occurrence)
  local keymap = KEYMAP_CACHE[occurrence.buffer]
  if keymap then
    keymap:reset()
    KEYMAP_CACHE[occurrence.buffer] = nil
    log.debug("Deactivated keybindings for buffer", occurrence.buffer)
  end
end)

return M
