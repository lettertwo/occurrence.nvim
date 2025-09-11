local Action = require("occurrence.Action")
local Config = require("occurrence.Config")
local Cursor = require("occurrence.Cursor")
local Occurrence = require("occurrence.Occurrence")
local Keymap = require("occurrence.Keymap")
local Range = require("occurrence.Range")

local log = require("occurrence.log")
local operators = require("occurrence.operators")
local set_opfunc = require("occurrence.set_opfunc")

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
    -- clear the hlsearch as we're going to to replace it with occurrence highlights.
    vim.cmd.nohlsearch()
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

---@param operator string
---@param config? occurrence.Config
actions.operate_motion = Action.new(function(occurrence, operator, config)
  local operators_config = config and config:keymap().operators or nil
  local operator_name = operators.resolve_name(operator, operators_config)
  local normal_action = operators.get_operator(operator, config)

  log.debug("Setting up operator:", operator, "->", operator_name)

  set_opfunc({
    operator = operator_name,
    occurrence = occurrence,
    count = vim.v.count,
    register = vim.v.register,
  }, function(state)
    state.count = vim.v.count > 0 and vim.v.count or state.count
    state.register = vim.v.register

    normal_action(
      state.occurrence,
      state.operator,
      Range.of_motion(state.type),
      state.count,
      state.register,
      state.type
    )

    if not occurrence:has_marks() then
      log.debug("Occurrence has no marks after operation; deactivating")
      actions.deactivate(occurrence)
    end
  end)

  -- send g@ to trigger custom opfunc
  return "g@"
end)

---@param operator string
---@param config? occurrence.Config
actions.operate_selection = Action.new(function(occurrence, operator, config)
  local selection_range = Range.of_selection()

  if not selection_range then
    log.error("No visual selection found for operator", operator)
    return
  end

  local normal_action = operators.get_operator(operator, config)
  local count, register = vim.v.count, vim.v.register

  -- Run the operator
  normal_action(occurrence, operator, selection_range, count, register, nil)

  -- Clear visual selection
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)

  -- Move the cursor back to the start of the selection.
  -- This seems to be what nvim does after a visual operation?
  Cursor.move(selection_range.start)

  if not occurrence:has_marks() then
    log.debug("Occurrence has no marks after operation; deactivating")
    actions.deactivate(occurrence)
  end
end)

-- Activate keybindings for the given configuration.
---@param occurrence occurrence.Occurrence
---@param opts? occurrence.Config | occurrence.Options
actions.activate_preset = Action.new(function(occurrence, opts)
  local config = Config.new(opts)

  if not occurrence:has_matches() then
    log.warn("No matches found for pattern(s):", table.concat(occurrence.patterns, ", "), "skipping activation")
    return
  end

  local cancel_action = (actions.unmark_all + actions.deactivate):with(occurrence)

  -- TODO: derive keymaps from config
  log.debug("Activating keybindings for buffer", occurrence.buffer)
  local keymap = Keymap.new(occurrence.buffer)

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

  local operators_keymap = config:keymap().operators

  if vim.iter(operators_keymap):any(function(_, v)
    return v ~= false
  end) then
    for operator_key in pairs(operators_keymap) do
      local operator_config = operators.get_operator_config(operator_key, operators_keymap)
      if operator_config == false then
        log.debug("Skipping operator key:", operator_key, "as it is disabled in the config")
        goto continue
      end
      local desc = "'" .. operator_key .. "' on marked occurrences"
      if type(operator_config) == "table" and operator_config.desc then
        desc = operator_config.desc
      end

      log.debug("Setting up operator key:", operator_key, "->", desc)
      keymap:n(
        operator_key,
        actions.operate_motion:bind(operator_key, config):with(occurrence),
        { desc = desc, expr = true }
      )
      desc = desc .. " in selection"
      keymap:x(operator_key, actions.operate_selection:bind(operator_key, config):with(occurrence), { desc = desc })

      ::continue::
    end
  end
end)

-- Activate operator-pending keybindings for the given configuration.
---@param occurrence occurrence.Occurrence
---@param config occurrence.Config
actions.activate_opfunc = Action.new(function(occurrence, config)
  local operator, count, register = vim.v.operator, vim.v.count, vim.v.register
  if not operators.is_supported(operator, config) then
    log.warn("Operator not supported:", operator)
    return
  end

  if not occurrence:has_matches() then
    actions.mark_cursor_word(occurrence)
  end

  if not occurrence:has_marks() then
    actions.mark_all(occurrence)
  end

  local operator_action = operators.get_operator(operator, config)
  local clear_action = actions.unmark_all + actions.deactivate
  local cancel_action = clear_action:with(occurrence)
  operator_action = operator_action + clear_action

  log.debug("Activating operator-pending keybindings for buffer", occurrence.buffer)
  local keymap = Keymap.new(occurrence.buffer)
  keymap:o("<Esc>", cancel_action, "Clear occurrence")
  keymap:o("<C-c>", cancel_action, "Clear occurrence")
  keymap:o("<C-[>", cancel_action, "Clear occurrence")

  -- Repeat operator_pending key to apply operator to the occurrences in the current line
  -- TODO: should this be configurable? Also, should it apply to all occurrences instead?
  keymap:o(config:keymap().operator_pending, "<cmd>normal! ^v$<cr>", "Operate on occurrences linewise")

  set_opfunc({
    operator = operator,
    count = count,
    register = register,
    occurrence = occurrence,
  }, function(state)
    state.count = vim.v.count > 0 and vim.v.count or state.count
    state.register = vim.v.register

    if not state.occurrence then
      state.occurrence = Occurrence.new()
      actions.mark_cursor_word(state.occurrence)
    end

    operator_action(
      state.occurrence,
      state.operator,
      Range.of_motion(state.type),
      state.count,
      state.register,
      state.type
    )
  end)

  -- send <C-\><C\n> to cancel pending op, followed by g@ to trigger custom opfunc
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.schedule(function()
    -- enter operator-pending mode
    vim.api.nvim_feedkeys("g@", "n", true)
  end)
  return vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
end)

-- Deactivate the keymap for the given occurrence.
actions.deactivate = Action.new(function(occurrence)
  if occurrence:has_marks() then
    log.debug("Occurrence still has marks during deactivate")
    occurrence:unmark()
  end
  if Keymap.del(occurrence.buffer) then
    log.debug("Deactivated keybindings for buffer", occurrence.buffer)
  end
end)

return actions
