---@module 'occurrence.api'

-- Modify a pending operator to operate on occurrences within a motion.
--
-- When used in operator-pending mode (e.g., `doip`), this modifies
-- the pending operator (`d`) to operate on all occurrences within
-- the motion (`ip` = inner paragraph).
--
-- If no patterns exist, adds pattern for word under cursor.
-- If no marks exist after callback, the operation is cancelled.
---@type occurrence.OperatorModifierConfig
local modify_operator = {
  mode = "o",
  expr = true,
  default_global_key = "o",
  plug = "<Plug>(OccurrenceModifyOperator)",
  desc = "Occurrences",
  type = "operator-modifier",
  callback = function(occurrence)
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
  default_global_key = "go",
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceMark)",
  desc = "Mark occurrence",
  callback = function(occurrence, args)
    local visual = (args and args.range ~= nil) or (vim.fn.mode():match("[vV]") ~= nil)
    local hlsearch = (args and args[1] ~= nil) or (vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= "")
    local count = args and args.count or (vim.v.count > 0 and vim.v.count or nil)
    local cursor = require("occurrence.Cursor").save()
    local new_pattern = nil

    if occurrence:has_matches() then
      if visual then
        local selection_range = args and args.range or require("occurrence.Range").of_selection()
        if selection_range and occurrence:has_matches(selection_range) then
          for range in occurrence:matches(selection_range, count) do
            occurrence:mark(range)
          end
        else
          if occurrence:of_selection(count == nil, args and args.range or nil) then
            new_pattern = occurrence.patterns[#occurrence.patterns]
          end
        end
      elseif hlsearch then
        if occurrence:of_pattern(count == nil, args and args[1] or nil) then
          new_pattern = occurrence.patterns[#occurrence.patterns]
        end
      else
        local match = occurrence:match_cursor()
        if match and match:contains(cursor.location) then
          for range in occurrence:matches(cursor.location, count or 1) do
            occurrence:mark(range)
          end
        else
          cursor:restore()
          if occurrence:of_word(count == nil) then
            new_pattern = occurrence.patterns[#occurrence.patterns]
          end
        end
      end
    elseif visual then
      if occurrence:of_selection(count == nil, args and args.range or nil) then
        new_pattern = occurrence.patterns[#occurrence.patterns]
      end
    elseif hlsearch then
      if occurrence:of_pattern(count == nil, args and args[1] or nil) then
        new_pattern = occurrence.patterns[#occurrence.patterns]
      end
    elseif occurrence:of_word(count == nil) then
      new_pattern = occurrence.patterns[#occurrence.patterns]
    end

    if count ~= nil and new_pattern then
      for range in occurrence:matches(cursor.location, count, new_pattern) do
        occurrence:mark(range)
      end
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
  callback = function(occurrence, args)
    local visual = (args and args.range ~= nil) or (vim.fn.mode():match("[vV]") ~= nil)
    local count = args and args.count or (vim.v.count > 0 and vim.v.count or nil)

    if occurrence:has_matches() then
      if visual then
        local selection_range = args and args.range or require("occurrence.Range").of_selection()
        if selection_range then
          for range in occurrence:matches(selection_range, count) do
            occurrence:unmark(range)
          end
        end
      else
        for range in occurrence:matches(require("occurrence.Location").of_cursor(), count or 1) do
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
  callback = function(occurrence, args)
    local visual = (args and args.range ~= nil) or (vim.fn.mode():match("[vV]") ~= nil)
    local hlsearch = (args and args[1] ~= nil) or (vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= "")
    local count = args and args.count or (vim.v.count > 0 and vim.v.count or nil)
    local cursor = require("occurrence.Cursor").save()
    local new_pattern = nil

    if occurrence:has_matches() then
      if visual then
        local selection_range = args and args.range or require("occurrence.Range").of_selection()
        if selection_range and occurrence:has_matches(selection_range) then
          for range in occurrence:matches(selection_range, count) do
            if not occurrence:mark(range) then
              occurrence:unmark(range)
            end
          end
        end
      elseif hlsearch then
        if occurrence:of_pattern(false, args and args[1] or nil) then
          new_pattern = occurrence.patterns[#occurrence.patterns]
        end
      else
        local match = occurrence:match_cursor()
        if match and match:contains(cursor.location) then
          for range in occurrence:matches(cursor.location, count or 1) do
            if not occurrence:mark(range) then
              occurrence:unmark(range)
            end
          end
        else
          cursor:restore()
          if occurrence:of_word() then
            new_pattern = occurrence.patterns[#occurrence.patterns]
          end
        end
      end
    elseif visual then
      if occurrence:of_selection(false, args and args.range or nil) then
        new_pattern = occurrence.patterns[#occurrence.patterns]
      end
    elseif hlsearch then
      if occurrence:of_pattern(false, args and args[1] or nil) then
        new_pattern = occurrence.patterns[#occurrence.patterns]
      end
    elseif occurrence:of_word() then
      new_pattern = occurrence.patterns[#occurrence.patterns]
    end

    if new_pattern then
      for range in occurrence:matches(cursor.location, count or 1, new_pattern) do
        occurrence:mark(range)
      end
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
  callback = function(occurrence, args)
    if not occurrence:has_matches() then
      mark.callback(occurrence)
    end
    local count = args and args.count or vim.v.count1
    -- if count is given as an argument, use that instead.
    if args and args[1] ~= nil then
      count = tonumber(args[1], 10) or count
    end
    for _ = 1, count do
      occurrence:match_cursor({ direction = "forward", marked = true, wrap = true })
    end
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
  callback = function(occurrence, args)
    if not occurrence:has_matches() then
      mark.callback(occurrence)
    end
    local count = args and args.count or vim.v.count1
    -- if count is given as an argument, use that instead.
    if args and args[1] ~= nil then
      count = tonumber(args[1], 10) or count
    end
    for _ = 1, count do
      occurrence:match_cursor({ direction = "backward", marked = true, wrap = true })
    end
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
  callback = function(occurrence, args)
    if not occurrence:has_matches() then
      mark.callback(occurrence)
    end
    local count = args and args.count or vim.v.count1
    -- if count is given as an argument, use that instead.
    if args and args[1] ~= nil then
      count = tonumber(args[1], 10) or count
    end
    for _ = 1, count do
      occurrence:match_cursor({ direction = "forward", wrap = true })
    end
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
  callback = function(occurrence, args)
    if not occurrence:has_matches() then
      mark.callback(occurrence)
    end
    local count = args and args.count or vim.v.count1
    -- if count is given as an argument, use that instead.
    if args and args[1] ~= nil then
      count = tonumber(args[1], 10) or count
    end
    for _ = 1, count do
      occurrence:match_cursor({ direction = "backward", wrap = true })
    end
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
    occurrence:dispose()
    return false
  end,
}

---@enum (key) occurrence.KeymapAction
local api = {
  mark = mark,
  unmark = unmark,
  toggle = toggle,
  next = next,
  previous = previous,
  match_next = match_next,
  match_previous = match_previous,
  deactivate = deactivate,
  modify_operator = modify_operator,
}

---@type occurrence.OperatorConfig
local change = {
  desc = "Change marked occurrences",
  operator = function(_, ctx)
    if ctx.replacement == nil then
      local ok, input = pcall(vim.fn.input, {
        prompt = "Change to: ",
        cancelreturn = false,
      })
      if not ok then
        -- User cancelled with Ctrl-C - return false to abort operation
        ctx.replacement = false
      end
      ctx.replacement = input
    end

    return ctx.replacement
  end,
}

---@type occurrence.OperatorConfig
local delete = {
  desc = "Delete marked occurrences",
  inner = false,
  operator = function()
    return {}
  end,
}

---@type occurrence.OperatorConfig
local yank = {
  desc = "Yank marked occurrences",
  operator = function(_, ctx)
    return ctx.register ~= nil
  end,
}

---@type occurrence.OperatorConfig
local put = {
  desc = "Put text from register at marked occurrences",
  operator = function(_, ctx)
    if ctx.register == nil then
      return false
    end
    local text = ctx.register.text
    -- Clear register to avoid writing the text we back to it.
    ctx.register = nil
    return text
  end,
}

---@type occurrence.OperatorConfig
local distribute = {
  desc = "Distribute lines from register across marked occurrences",
  operator = function(current, ctx)
    if ctx.register == nil then
      return false
    end

    if ctx.replacement == nil then
      ctx.replacement = ctx.register.text
    end

    -- Clear register to avoid writing the text we back to it.
    ctx.register = nil

    if #ctx.replacement == 0 then
      return ""
    end

    -- Distribute lines cyclically across occurrences.
    local line_index = ((current.index - 1) % #ctx.replacement) + 1
    return ctx.replacement[line_index]
  end,
}

---@type occurrence.OperatorConfig
local indent_left = {
  desc = "Indent left marked occurrences",
  operator = "<",
}

---@type occurrence.OperatorConfig
local indent_right = {
  desc = "Indent right marked occurrences",
  operator = ">",
}

---@type occurrence.OperatorConfig
local indent_format = {
  desc = "Format indent of marked occurrences",
  operator = "=",
}

---@type occurrence.OperatorConfig
local lowercase = {
  desc = "Lowercase marked occurrences",
  operator = "u",
}

---@type occurrence.OperatorConfig
local uppercase = {
  desc = "Uppercase marked occurrences",
  operator = "U",
}

---@type occurrence.OperatorConfig
local swap_case = {
  desc = "Swap case of marked occurrences",
  operator = "~",
}

-- Supported operators
---@enum (key) occurrence.BuiltinOperator
local operators = {
  change = change,
  delete = delete,
  yank = yank,
  put = put,
  distribute = distribute,
  indent_left = indent_left,
  indent_right = indent_right,
  indent_format = indent_format,
  uppercase = uppercase,
  lowercase = lowercase,
  swap_case = swap_case,
}

return vim.tbl_extend("error", api, operators)
