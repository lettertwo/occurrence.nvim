local Action = require("occurrence.Action")
local Cursor = require("occurrence.Cursor")
local Keymap = require("occurrence.Keymap")
local Range = require("occurrence.Range")
local O = require("occurrence.operators")

local log = require("occurrence.log")

-- A map of Buffer ids to their active keymaps.
---@type table<integer, Keymap>
local KEYMAP_CACHE = {}

local original_opfunc = vim.go.operatorfunc

-- Based on https://github.com/neovim/neovim/issues/14157#issuecomment-1320787927
local _set_opfunc = vim.fn[vim.api.nvim_exec2(
  [[
  func s:set_opfunc(val)
    let &opfunc = a:val
  endfunc
  echon get(function('s:set_opfunc'), 'name')
]],
  { output = true }
).output]

local set_opfunc = function(opfunc)
  original_opfunc = vim.go.operatorfunc
  _set_opfunc(opfunc)
end

local reset_opfunc = function()
  _set_opfunc(original_opfunc)
end

---@param mode string
local function setmode(mode)
  if mode == vim.api.nvim_get_mode().mode then
    return true
  end
  if mode == "n" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  elseif mode == "i" then
    vim.cmd("startinsert")
  else
    error("Unsupported mode: " .. mode)
  end
  return mode == vim.api.nvim_get_mode().mode
end

---@class OccurrenceActions
local A = {}

-- Find all occurrences of the word under the cursor in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
A.find_cursor_word = Action.new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
  assert(word ~= "", "no word under cursor")
  occurrence:set(word, { is_word = true })
end)

-- Find all occurrences of the visually selected text in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
A.find_visual_subword = Action.new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  local text = table.concat(vim.api.nvim_buf_get_text(0, pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3], {}))
  assert(text ~= "", "no text selected")
  occurrence:set(text)
  setmode("n")
end)

-- Find all occurrences using the last search pattern.
A.find_last_search = Action.new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local pattern = vim.fn.getreg("/")
  assert(pattern ~= "", "no search pattern available")

  -- Convert vim search pattern to occurrence pattern
  -- Remove leading/trailing delimiters and escape for literal search if needed
  local cleaned_pattern = pattern:gsub("^\\v", ""):gsub("^\\V", "")

  -- For now, treat search patterns as literal text
  -- TODO: Add support for regex patterns in future
  occurrence:set(cleaned_pattern, { is_word = false })
end)

-- Find all occurrences using the current search pattern if available,
-- otherwise use the word under the cursor.
A.find_active_search_or_cursor_word = Action.new(function(occurrence)
  if vim.v.hlsearch == 1 then
    return A.find_last_search:with(occurrence)()
  end
  return A.find_cursor_word:with(occurrence)()
end)

-- Go to the next occurrence.
A.goto_next = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "forward", wrap = true })
end)

-- Go to the previous occurrence.
A.goto_previous = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "backward", wrap = true })
end)

-- Go to the next mark.
A.goto_next_mark = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
end)

-- Go to the previous mark.
A.goto_previous_mark = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
end)

-- Add a mark and highlight for the current match of the given occurrence.
A.mark = Action.new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    occurrence:mark(range)
  end
end)

-- Remove a mark and highlight for the current match of the given occurrence.
A.unmark = Action.new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    occurrence:unmark(range)
  end
end)

-- Toggle a mark and highlight for the current match of the given occurrence.
A.toggle_mark = Action.new(function(occurrence)
  local range = occurrence:match_cursor()
  log("toggle_mark", range)
  if range then
    if not occurrence:mark(range) then
      occurrence:unmark(range)
    end
  end
end)

-- Add marks and highlights for matches of the given occurrence within the current selection.
A.mark_selection = Action.new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:matches(selection_range) do
      occurrence:mark(range)
    end
  end
end)

-- Clear marks and highlights for matches of the given occurrence within the current selection.
A.unmark_selection = Action.new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:marks({ range = selection_range }) do
      occurrence:unmark(range)
    end
  end
end)

-- Toggle marks and highlights for matches of the given occurrence within the current selection.
A.toggle_mark_selection = Action.new(function(occurrence)
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
A.mark_all = Action.new(function(occurrence)
  for range in occurrence:matches() do
    occurrence:mark(range)
  end
end)

-- Clear all marks and highlights for the given occcurrence.
A.unmark_all = Action.new(function(occurrence)
  for range in occurrence:marks() do
    occurrence:unmark(range)
  end
end)

-- Activate keybindings for the given configuration.
---@param occurrence Occurrence
---@param config OccurrenceConfig
A.activate = Action.new(function(occurrence, config)
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

  local cancel_action = (A.unmark_all + A.deactivate):with(occurrence)

  -- TODO: derive keymaps from config

  -- Cancel the pending occurrence operation.
  keymap:n("<Esc>", cancel_action, "Clear occurrence")
  -- keymap:n("<C-c>", cancel_action, "Clear occurrence")
  -- keymap:n("<C-[>", cancel_action, "Clear occurrence")

  -- Navigate between occurrence matches
  keymap:n("n", A.goto_next_mark:with(occurrence), "Next marked occurrence")
  keymap:n("N", A.goto_previous_mark:with(occurrence), "Previous marked occurrence")
  keymap:n("gn", A.goto_next:with(occurrence), "Next occurrence")
  keymap:n("gN", A.goto_previous:with(occurrence), "Previous occurrence")

  -- Manage occurrence marks.
  keymap:n("go", A.toggle_mark:with(occurrence), "Toggle occurrence mark")
  keymap:n("ga", A.mark:with(occurrence), "Mark occurrence")
  keymap:n("gx", A.unmark:with(occurrence), "Unmark occurrence")

  -- Use visual/select to narrow occurrence matches.
  keymap:x("go", A.toggle_mark_selection:with(occurrence), "Toggle occurrence marks")
  keymap:x("ga", A.mark_selection:with(occurrence), "Mark occurrences")
  keymap:x("gx", A.unmark_selection:with(occurrence), "Unmark occurrences")

  -- Delete marked occurrences.
  -- TODO: add shortcuts like "dd", "dp", etc.
  -- keymap:n("d", create_opfunc(M.delete_motion:with(occurrence)), { expr = true, desc = "Delete marked occurrences" })
  -- keymap:x("d", (A.delete_in_selection):with(occurrence), "Delete marked occurrences")
end)

-- Activate operator-pending keybindings for the given configuration.
---@param occurrence Occurrence
---@param config OccurrenceConfig
A.activate_opfunc = Action.new(function(occurrence, config)
  if not occurrence:has_matches() then
    log.debug("No matches found for pattern:", occurrence.pattern, "skipping activation")
    return
  end

  local operator, count, register = vim.v.operator, vim.v.count, vim.v.register

  local operator_action = O[operator]

  if not operator_action then
    -- Try generic fallback if available
    if O.get_operator then
      operator_action = O.get_operator(operator)
    else
      log.error("Unsupported operator for opfunc_motion:", operator)
      return
    end
  end

  local cancel_action = (A.unmark_all + A.deactivate):with(occurrence)

  operator_action = operator_action:with(occurrence) + cancel_action

  log.debug("Activating operator-pending keybindings for buffer", occurrence.buffer)
  if KEYMAP_CACHE[occurrence.buffer] then
    log.error("Keymap is already active!")
    KEYMAP_CACHE[occurrence.buffer]:reset()
  end
  local keymap = Keymap:new(occurrence.buffer)
  KEYMAP_CACHE[occurrence.buffer] = keymap

  keymap:o("<Esc>", cancel_action, "Clear occurrence")
  keymap:o("<C-c>", cancel_action, "Clear occurrence")
  keymap:o("<C-[>", cancel_action, "Clear occurrence")
  keymap:o(config.keymap.operator_pending, "<cmd>normal! ^v$<cr>", "Operate on occurrences linewise")

  local cursor = Cursor:save()

  set_opfunc(function(type)
    operator_action(operator, Range:of_motion(type), count, register, type)
    cursor:restore()
  end)

  -- send ctrl-c to cancel pending op, followed by g@ to trigger custom opfunc
  return vim.api.nvim_replace_termcodes("<C-c>g@", true, false, true)
end)

-- Deactivate the keymap for the given occurrence.
A.deactivate = Action.new(function(occurrence)
  local keymap = KEYMAP_CACHE[occurrence.buffer]
  if keymap then
    keymap:reset()
    KEYMAP_CACHE[occurrence.buffer] = nil
    log.debug("Deactivated keybindings for buffer", occurrence.buffer)
  end

  reset_opfunc()
end)

return A
