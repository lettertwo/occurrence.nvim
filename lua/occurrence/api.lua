---@module 'occurrence.api'

local log = require("occurrence.log")

-- Whether the editor is in any Visual mode: charwise `v`, linewise `V`,
-- or blockwise `^V` (`"\22"`, which a bare `[vV]` pattern misses).
---@return boolean
local function in_visual_mode()
  return vim.fn.mode():match("[vV\22]") ~= nil
end

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
    local visual = (args and args.range ~= nil) or in_visual_mode()
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
    local visual = (args and args.range ~= nil) or in_visual_mode()
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
    local visual = (args and args.range ~= nil) or in_visual_mode()
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

-- Invert the dispose-after-operator decision for the next operator only.
-- When `dispose_after_operator` is `true` (the default), this prevents
-- occurrence mode from exiting after the next operator, enabling
-- one-off chaining (e.g., `gU` then `y` on the same marks).
-- When `dispose_after_operator` is `false`, this forces occurrence
-- mode to exit after the next operator.
-- Press again to cancel the inversion before running an operator.
---@type occurrence.OccurrenceModeConfig
local toggle_dispose = {
  mode = { "n", "v" },
  desc = "Toggle dispose after next operator",
  plug = "<Plug>(OccurrenceToggleDispose)",
  type = "occurrence-mode",
  callback = function(occurrence)
    occurrence:toggle_dispose_next()
  end,
}

-- Compute cursor positions for `marks` and schedule `mcursor.add` once the
-- current event loop tick finishes, so it runs after occurrence's own
-- opfunc/dispose machinery (including the `g@$` restore feed) has settled.
-- Shared by the `cursors` action and the `cursors_start`/`cursors_end`/
-- `change_cursors` operators (`make_cursor_operator` below).
--
-- `where == "end"` takes the last character of each mark (so `a` appends
-- after every occurrence, and marks ending at EOL behave like any other);
-- otherwise `range.start` (used as-is for `"start"` and for `"change"`,
-- where the mark's range has already collapsed to the insertion point).
--
-- The primary cursor is the mark whose range contains the window cursor,
-- if any; `mcursor.add` falls back to the nearest location otherwise.
-- The buffer is captured now (not read back from the scheduled closure),
-- since occurrence mode -- and the marks tracking it -- may be disposed by
-- the time the closure runs.
---@param occurrence occurrence.Occurrence
---@param marks [integer, occurrence.Range][]
---@param where "start" | "end" | "change"
local function schedule_cursors(occurrence, marks, where)
  if #marks == 0 then
    return
  end

  local Location = require("occurrence.Location")
  local buffer = occurrence.buffer
  local cursor = Location.of_cursor()

  -- `range.stop` is end-exclusive, so the last character of the mark is the
  -- codepoint that ends at `stop.col`. A Normal-mode cursor cannot sit past
  -- EOL, but `nvim_mcursor` accepts that column, so using `stop` directly
  -- would put the primary and the extras on different columns for a mark
  -- ending at EOL. Landing on the last character avoids that entirely.
  ---@param range occurrence.Range
  ---@return occurrence.Location
  local function last_char(range)
    local stop = range.stop
    if stop.col == 0 then
      return stop
    end
    local line = vim.api.nvim_buf_get_lines(buffer, stop.line, stop.line + 1, false)[1] or ""
    -- str_utf_start takes a 1-based byte index and returns the (non-positive)
    -- offset to the start of the codepoint containing that byte.
    local col = stop.col - 1
    if col < #line then
      col = col + vim.str_utf_start(line, col + 1)
    end
    return Location.new(stop.line, math.max(col, 0))
  end

  ---@type occurrence.Location[]
  local positions = {}
  ---@type integer?
  local primary_index = nil
  for i, entry in ipairs(marks) do
    local _, range = unpack(entry)
    table.insert(positions, where == "end" and last_char(range) or range.start)
    if primary_index == nil and cursor and range:contains(cursor) then
      primary_index = i
    end
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buffer) or buffer ~= vim.api.nvim_get_current_buf() then
      log.debug("Skipping deferred mcursor.add: buffer", buffer, "is no longer current")
      return
    end
    local ok, err = pcall(
      require("occurrence.mcursor").add,
      positions,
      { primary = primary_index, buf = buffer, follow = require("occurrence.Config").get().follow_cursors }
    )
    if not ok then
      log.debug("Deferred mcursor.add failed:", err)
    end
  end)
end

-- Convert marked occurrences to native `:h multicursor` cursors and hand
-- the buffer over to Neovim.
--
-- Occurrence mode has no way to observe a native multicursor session
-- (it fires no autocmd and has no mode of its own), so this always
-- disposes occurrence mode once cursors are placed. That also drops the
-- buffer-local keymaps (`<Esc>`, `n`, `N`, `c`, `d`, ...) that would
-- otherwise shadow native multicursor workflows.
--
-- In visual mode, only marks within the selection are converted.
-- Otherwise, all marks are converted.
--
-- If occurrence has no matches yet, marks the word under the cursor
-- first (like `next`), then converts.
--
-- Requires Neovim 0.13+ with `vim.api.nvim_mcursor`.
---@type occurrence.OccurrenceModeConfig
local cursors = {
  mode = { "n", "v" },
  type = "occurrence-mode",
  plug = "<Plug>(OccurrenceCursors)",
  desc = "Convert marked occurrences to cursors",
  callback = function(occurrence, args)
    local mcursor = require("occurrence.mcursor")
    if not mcursor.is_supported() then
      log.error(mcursor.unsupported_message())
      return false
    end

    if not occurrence:has_matches() then
      mark.callback(occurrence, args)
    end

    local visual = (args and args.range ~= nil) or in_visual_mode()
    local scope = visual and (args and args.range or require("occurrence.Range").of_selection()) or nil

    -- The selection has been consumed. Leave Visual mode now, before the
    -- scheduled `Cursor.move(primary)` runs, or that move would extend the
    -- selection instead of placing the primary cursor.
    if in_visual_mode() then
      require("occurrence.feedkeys").change_mode("n", { noflush = true, silent = true })
    end

    local marks = occurrence.extmarks:collect(scope)
    if #marks == 0 then
      log.warn("No marked occurrences to convert to cursors")
      return false
    end

    -- Cursors must be created after occurrence mode has fully torn down
    -- (including the buffer-local keymaps disposed below), since
    -- `nvim_mcursor` is a silent no-op while any cascade is running.
    schedule_cursors(occurrence, marks, "start")

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
  toggle_dispose = toggle_dispose,
  cursors = cursors,
  modify_operator = modify_operator,
}

---@type occurrence.OperatorConfig
local change = {
  desc = "Change marked occurrences",
  before = function(_, ctx)
    local ok, input = pcall(vim.fn.input, {
      prompt = "Change to: ",
      cancelreturn = false,
    })
    if not ok then
      -- User cancelled with Ctrl-C - return false to abort operation
      return false
    end
    ctx.replacement = input
  end,
  operator = function(_, ctx)
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

-- Build one of the `cursors_start` / `cursors_end` / `change_cursors`
-- operators. `where` is `"start"` (cursor on the first character) or
-- `"end"` (cursor on the last character, so `a` appends after the mark);
-- both are side effect only, the mark text is untouched. Or it is
-- or `"change"` to delete the mark text and place a cursor at the
-- resulting insertion point, then enter insert mode.
--
-- These are motion-scoped siblings of the `cursors` action: `Iip`/`Aip`
-- convert only marks within `ip`, rather than every mark. `change_cursors`
-- is the default `c` when native multicursor is available, in occurrence
-- mode (`go` then `cip`) and operator-pending mode (`coip`).
--
-- `dispose_after_operator` is forced `true` regardless of the global
-- `dispose_after_operator` option, since occurrence mode cannot coexist
-- with a native multicursor session (see `cursors` above).
---@param where "start" | "end" | "change"
---@return occurrence.OperatorConfig
local function make_cursor_operator(where)
  return {
    desc = where == "start" and "Convert marked occurrences to cursors at their start"
      or where == "end" and "Convert marked occurrences to cursors on their last character"
      or "Delete marked occurrences, convert to cursors, and insert",
    -- `c` is a real Vim operator, so `change_cursors` is also reachable from
    -- operator-pending mode (`coip`) via `modify_operator`: it cancels the
    -- pending `c` and re-runs this same opfunc over the marks in the motion,
    -- exactly like `cip` in occurrence mode. `I`/`A` are not operators, so
    -- `"o"` never triggers for the other two.
    mode = where == "change" and { "n", "v", "o" } or { "n", "v" },
    dispose_after_operator = true,
    before = function(_, _ctx)
      local mcursor = require("occurrence.mcursor")
      if not mcursor.is_supported() then
        log.error(mcursor.unsupported_message())
        return false
      end
    end,
    operator = function()
      if where == "change" then
        -- Delete the mark text; `after` reads the collapsed insertion
        -- point from the updated (post-edit) mark position.
        return {}
      end
      -- Side effect only: unmark without editing, so the mark's range
      -- is unchanged when `after` reads it back. `nil` (not `true`):
      -- `true` is treated the same for unmarking, but also gets read as
      -- "yanked" and saved to the register, which we don't want here.
      return nil
    end,
    after = function(marks, ctx)
      if #marks == 0 then
        return
      end

      schedule_cursors(ctx.occurrence, marks, where)

      if where == "change" then
        -- Deferred for the same reason `schedule_cursors` defers: entering
        -- insert must happen only after occurrence's opfunc/dispose
        -- machinery (including the `g@$` restore feed) has fully finished.
        vim.schedule(function()
          -- Enter insert via `nvim_input`, not `feedkeys`/`startinsert`.
          -- `startinsert` only sets `restart_edit` for a Normal() loop to
          -- notice, and there is none in this deferred context. A queued
          -- `feedkeys("i")` does enter insert, but the multicursor cascade
          -- arms its *live* per-cursor preview only for insert entered by a
          -- clean top-level command; a typeahead `i` consumed alongside the
          -- user's first keystroke does not qualify, so cursors would only
          -- commit the text on `<Esc>`, not mirror it as typed. `nvim_input`
          -- injects `i` into the low-level input queue exactly as a real
          -- keypress, which is that clean insert-entry edge.
          --
          -- It is inert under a headless/no-UI harness (the input queue is
          -- not pumped), so tests cannot exercise the insert entry; the
          -- cascade needs interactive verification either way.
          vim.api.nvim_input("i")
        end)
      end
    end,
  }
end

---@type occurrence.OperatorConfig
local cursors_start = make_cursor_operator("start")

---@type occurrence.OperatorConfig
local cursors_end = make_cursor_operator("end")

---@type occurrence.OperatorConfig
local change_cursors = make_cursor_operator("change")

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
  cursors_start = cursors_start,
  cursors_end = cursors_end,
  change_cursors = change_cursors,
}

return vim.tbl_extend("error", api, operators, {
  operators = operators,
  actions = api,
})
