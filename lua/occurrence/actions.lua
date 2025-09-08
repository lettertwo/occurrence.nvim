local Action = require("occurrence.Action")
local Config = require("occurrence.Config")
local Cursor = require("occurrence.Cursor")
local Occurrence = require("occurrence.Occurrence")
local Keymap = require("occurrence.Keymap")
local Range = require("occurrence.Range")

local log = require("occurrence.log")
local operators = require("occurrence.operators")

-- A map of Buffer ids to their active keymaps.
---@type table<integer, occurrence.Keymap>
local KEYMAP_CACHE = {}

-- A map of Window ids to their cached cursor positions.
---@type table<integer, occurrence.Cursor>
local CURSOR_CACHE = {}

---@type integer?
local watching_dot_repeat

local function watch_dot_repeat()
  if watching_dot_repeat == nil then
    watching_dot_repeat = vim.on_key(function(char)
      if char == "." then
        local win = vim.api.nvim_get_current_win()
        CURSOR_CACHE[win] = Cursor.save()
        log.debug("Updating cached cursor position for dot-repeat to", CURSOR_CACHE[win].location)
      end
    end)
  end
  log.debug("Watching for dot-repeat to cache cursor position")
end

-- Based on https://github.com/neovim/neovim/issues/14157#issuecomment-1320787927
local set_opfunc = vim.fn[vim.api.nvim_exec2(
  [[
  func! s:set_opfunc(val)
    let &opfunc = a:val
  endfunc
  echon get(function('s:set_opfunc'), 'name')
]],
  { output = true }
).output]

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

---@module 'occurrence.actions'
local actions = {}

-- Find all occurrences of the word under the cursor in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
actions.find_cursor_word = Action.new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
  if word == "" then
    log.warn("No word under cursor")
    return
  end
  occurrence:add(word, { is_word = true })
end)

-- Find all occurrences of the visually selected text in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
actions.find_visual_subword = Action.new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
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
  occurrence:add(text)
  setmode("n")
end)

-- Find all occurrences using the last search pattern.
actions.find_last_search = Action.new(function(occurrence)
  assert(occurrence.buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local pattern = vim.fn.getreg("/")

  if pattern == "" then
    log.warn("No search pattern available")
    return
  end

  -- Convert vim search pattern to occurrence pattern
  -- Remove leading/trailing delimiters and escape for literal search if needed
  local cleaned_pattern = pattern:gsub("^\\v", ""):gsub("^\\V", "")

  -- For now, treat search patterns as literal text
  -- TODO: Add support for regex patterns in future
  occurrence:add(cleaned_pattern, { is_word = false })
end)

-- Find all occurrences using the current search pattern if available,
-- otherwise use the word under the cursor.
actions.find_active_search_or_cursor_word = Action.new(function(occurrence)
  if vim.v.hlsearch == 1 then
    return actions.find_last_search:with(occurrence)()
  end
  return actions.find_cursor_word:with(occurrence)()
end)

-- Go to the next occurrence.
actions.goto_next = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "forward", wrap = true })
end)

-- Go to the previous occurrence.
actions.goto_previous = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "backward", wrap = true })
end)

-- Go to the next mark.
actions.goto_next_mark = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
end)

-- Go to the previous mark.
actions.goto_previous_mark = Action.new(function(occurrence)
  occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
end)

-- Add a mark and highlight for the current match of the given occurrence.
actions.mark = Action.new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    occurrence:mark(range)
  end
end)

-- Remove a mark and highlight for the current match of the given occurrence.
actions.unmark = Action.new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    occurrence:unmark(range)
  end
end)

-- Toggle a mark and highlight for the current match of the given occurrence.
actions.toggle_mark = Action.new(function(occurrence)
  local range = occurrence:match_cursor()
  if range then
    if not occurrence:mark(range) then
      occurrence:unmark(range)
    end
  end
end)

-- Add marks and highlights for matches of the given occurrence within the current selection.
actions.mark_selection = Action.new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:matches(selection_range) do
      occurrence:mark(range)
    end
  end
end)

-- Clear marks and highlights for matches of the given occurrence within the current selection.
actions.unmark_selection = Action.new(function(occurrence)
  local selection_range = Range:of_selection()
  if selection_range then
    for range in occurrence:marks({ range = selection_range }) do
      occurrence:unmark(range)
    end
  end
end)

-- Toggle marks and highlights for matches of the given occurrence within the current selection.
actions.toggle_mark_selection = Action.new(function(occurrence)
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
actions.mark_all = Action.new(function(occurrence)
  for range in occurrence:matches() do
    occurrence:mark(range)
  end
end)

-- Clear all marks and highlights for the given occurrence.
actions.unmark_all = Action.new(function(occurrence)
  for range in occurrence:marks() do
    occurrence:unmark(range)
  end
end)

actions.mark_cursor_word = Action.new(function(occurrence)
  actions.find_cursor_word(occurrence)
  -- mark all occurrences of the newest pattern
  if occurrence.patterns ~= nil and #occurrence.patterns > 0 then
    local pattern = occurrence.patterns[#occurrence.patterns]
    for range in occurrence:matches(nil, pattern) do
      occurrence:mark(range)
    end
  end
end)

actions.mark_cursor_word_or_toggle_mark = Action.new(function(occurrence)
  if occurrence.patterns == nil or #occurrence.patterns == 0 then
    return actions.mark_cursor_word(occurrence)
  end
  local cursor = Cursor.save()
  local range = occurrence:match_cursor()
  if range and range:contains(cursor.location) then
    return actions.toggle_mark(occurrence)
  else
    cursor:restore()
    return actions.mark_cursor_word(occurrence)
  end
end)

actions.mark_visual_subword = actions.find_visual_subword + actions.mark_all

actions.mark_active_search_or_cursor_word = actions.find_active_search_or_cursor_word + actions.mark_all

actions.mark_last_search = actions.find_last_search + actions.mark_all

-- Activate keybindings for the given configuration.
---@param occurrence occurrence.Occurrence
---@param opts? occurrence.Config | occurrence.Options
actions.activate = Action.new(function(occurrence, opts)
  local config = Config.new(opts)

  if not occurrence:has_matches() then
    log.warn("No matches found for pattern(s):", table.concat(occurrence.patterns, ", "), "skipping activation")
    return
  end
  log.debug("Activating keybindings for buffer", occurrence.buffer)
  if KEYMAP_CACHE[occurrence.buffer] then
    log.error("Keymap is already active!")
    KEYMAP_CACHE[occurrence.buffer]:reset()
  end
  local keymap = Keymap.new(occurrence.buffer)
  KEYMAP_CACHE[occurrence.buffer] = keymap

  local cancel_action = (actions.unmark_all + actions.deactivate):with(occurrence)

  -- TODO: derive keymaps from config

  -- Cancel the pending occurrence operation.
  keymap:n("<Esc>", cancel_action, "Clear occurrence")
  -- keymap:n("<C-c>", cancel_action, "Clear occurrence")
  -- keymap:n("<C-[>", cancel_action, "Clear occurrence")

  -- Navigate between occurrence matches
  keymap:n("n", actions.goto_next_mark:with(occurrence), "Next marked occurrence")
  keymap:n("N", actions.goto_previous_mark:with(occurrence), "Previous marked occurrence")
  keymap:n("gn", actions.goto_next:with(occurrence), "Next occurrence")
  keymap:n("gN", actions.goto_previous:with(occurrence), "Previous occurrence")

  -- Manage occurrence marks.
  keymap:n("go", actions.mark_cursor_word_or_toggle_mark:with(occurrence), "Toggle occurrence mark")
  keymap:n("ga", actions.mark:with(occurrence), "Mark occurrence")
  keymap:n("gx", actions.unmark:with(occurrence), "Unmark occurrence")

  -- Use visual/select to narrow occurrence marks.
  keymap:x("go", actions.toggle_mark_selection:with(occurrence), "Toggle occurrence marks")
  keymap:x("ga", actions.mark_selection:with(occurrence), "Mark occurrences")
  keymap:x("gx", actions.unmark_selection:with(occurrence), "Unmark occurrences")

  -- Delete marked occurrences.
  -- TODO: add shortcuts like "dd", "dp", etc.
  -- keymap:n("d", create_opfunc(M.delete_motion:with(occurrence)), { expr = true, desc = "Delete marked occurrences" })
  -- keymap:x("d", (A.delete_in_selection):with(occurrence), "Delete marked occurrences")
end)

---@class occurrence.OpFuncState
---@field operator string The operator that triggered the opfunc.
---@field count integer The count given to the operator.
---@field register string The register given to the operator.
---@field cursor occurrence.Cursor? The cursor position before invoking the operator.
---@field occurrence occurrence.Occurrence? The occurrence being operated on.

-- Create a function to be used as 'opfunc' that performs the given action.
---@param operator occurrence.Action
---@param state occurrence.OpFuncState
---@return fun(type: string)
local function create_opfunc(operator, state)
  local function opfunc(type)
    if not state.cursor then
      local win = vim.api.nvim_get_current_win()
      state.cursor = CURSOR_CACHE[win] or Cursor.save()
      state.cursor:restore()
    end

    if not state.occurrence then
      state.occurrence = Occurrence.new()
      actions.find_cursor_word(state.occurrence)
      actions.mark_all(state.occurrence)
    end

    operator(state.occurrence, state.operator, Range.of_motion(type), state.count, state.register, type)
    state.cursor:restore()

    -- Reset state to allow dot-repatable operation on a different occurrence.
    state.occurrence = nil
    state.cursor = nil

    -- Watch for dot-repeat to cache cursor position prior to repeating the operation.
    watch_dot_repeat()
  end
  return opfunc
end

-- Activate operator-pending keybindings for the given configuration.
---@param occurrence occurrence.Occurrence
---@param config occurrence.Config
actions.activate_opfunc = Action.new(function(occurrence, config)
  if not occurrence:has_matches() then
    log.warn("No matches found for pattern:", occurrence.pattern, "skipping activation")
    return
  end

  local operator, count, register = vim.v.operator, vim.v.count, vim.v.register

  local operator_action = operators[operator]

  if not operator_action then
    -- Try generic fallback if available
    if operators.get_operator then
      operator_action = operators.get_operator(operator)
    else
      log.error("Unsupported operator for opfunc_motion:", operator)
      return
    end
  end

  local clear_action = actions.unmark_all + actions.deactivate

  operator_action = operator_action + clear_action

  log.debug("Activating operator-pending keybindings for buffer", occurrence.buffer)
  if KEYMAP_CACHE[occurrence.buffer] then
    log.error("Keymap is already active!")
    KEYMAP_CACHE[occurrence.buffer]:reset()
  end
  local keymap = Keymap.new(occurrence.buffer)
  KEYMAP_CACHE[occurrence.buffer] = keymap

  local cancel_action = clear_action:with(occurrence)
  keymap:o("<Esc>", cancel_action, "Clear occurrence")
  keymap:o("<C-c>", cancel_action, "Clear occurrence")
  keymap:o("<C-[>", cancel_action, "Clear occurrence")
  keymap:o(config.keymap.operator_pending, "<cmd>normal! ^v$<cr>", "Operate on occurrences linewise")

  log.debug("Caching cursor position for opfunc in buffer", occurrence.buffer)
  CURSOR_CACHE[occurrence.buffer] = Cursor.save()

  set_opfunc(create_opfunc(operator_action, {
    operator = operator,
    count = count,
    register = register,
    cursor = Cursor.save(),
    occurrence = occurrence,
  }))

  -- send ctrl-c to cancel pending op, followed by g@ to trigger custom opfunc
  return vim.api.nvim_replace_termcodes("<C-c>g@", true, false, true)
end)

-- Deactivate the keymap for the given occurrence.
actions.deactivate = Action.new(function(occurrence)
  if occurrence:has_marks() then
    log.warn("Occurrence still has marks, not deactivating keymap")
    return
  end
  local keymap = KEYMAP_CACHE[occurrence.buffer]
  if keymap then
    keymap:reset()
    KEYMAP_CACHE[occurrence.buffer] = nil
    log.debug("Deactivated keybindings for buffer", occurrence.buffer)
  end
end)

return actions
