local Cursor = require("occurrence.Cursor")
local Location = require("occurrence.Location")
local Range = require("occurrence.Range")
local Register = require("occurrence.Register")

local feedkeys = require("occurrence.feedkeys")
local log = require("occurrence.log")

---@module "occurrence.Operator"

-- A map of Window ids to their cached cursor positions.
---@type table<integer, occurrence.Cursor>
local CURSOR_CACHE = {}

vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("OccurrenceCursorCache", { clear = true }),
  callback = function(args)
    local win_id = tonumber(args.match)
    if win_id and CURSOR_CACHE[win_id] then
      CURSOR_CACHE[win_id] = nil
      log.debug("Cleared cached cursor position for closed window", win_id)
    end
  end,
})

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
local _set_opfunc = vim.fn[vim.api.nvim_exec2(
  [[
  func! s:set_opfunc(val)
    let &opfunc = a:val
  endfunc
  echon get(function('s:set_opfunc'), 'name')
]],
  { output = true }
).output]

---@class occurrence.OpfuncContext
---@field mode "n" | "v" | "o" The mode from which the opfunc is being executed
---@field count integer The count provided for the operation
---@field register string The register to use for the operation
---@field inner boolean Whether to operate on inner text only (no surrounding whitespace)

---@param occurrence occurrence.Occurrence The occurrence to operate on.
---@param operator string | occurrence.OperatorFn The operator to apply (e.g. "d", "y", etc), or a callback function that performs the operation.
---@param marks [integer, occurrence.Range][] The marks to operate on.
---@param ctx occurrence.OpfuncContext The opfunc context.
local function apply_operator(occurrence, operator, marks, ctx)
  local original_cursor = Cursor.save()

  if ctx.inner ~= true then
    -- expand all marks to include surrounding whitespace
    for i = 1, #marks do
      local id, mark = unpack(marks[i])

      -- search forward for next non-whitespace char
      original_cursor:move(mark.stop)
      local new_stop = Location.from_pos(vim.fn.searchpos([[\V\C\S]], "nWc"))
      if new_stop and new_stop > mark.stop then
        local new_mark = Range.new(mark.start, new_stop)
        log.debug("Expanded mark", id, "from", mark, "to", new_mark)
        marks[i] = { id, new_mark }
      else
        -- if no forward non-whitespace char was found,
        -- we must be at the end of a line,
        -- so search backward for previous non-whitespace char.
        original_cursor:move(mark.start)
        local new_start = Location.from_pos(vim.fn.searchpos([[\V\C\S\s]], "bnWe"))
        if new_start and new_start < mark.start then
          local new_mark = Range.new(new_start, mark.stop)
          log.debug("Expanded mark", id, "from", mark, "to", new_mark)
          marks[i] = { id, new_mark }
        end
      end
    end

    original_cursor:restore()
  end

  -- String operator: use feedkeys
  if type(operator) == "string" then
    local edited = 0
    local last_edited = nil

    -- Visually select and feedkeys for each mark in reverse order
    for i = #marks, 1, -1 do
      local id, mark = unpack(marks[i])
      -- Create single undo block for all edits
      if edited > 0 then
        vim.cmd("silent! undojoin")
      end

      Cursor.move(mark.start)
      feedkeys.change_mode("v", { force = true, silent = true })
      Cursor.move(mark.stop)
      occurrence.extmarks:unmark(id)
      feedkeys(operator, { noremap = true })

      edited = edited + 1
      last_edited = mark
    end

    if edited == 0 then
      log.debug("No marks to execute", operator)
    else
      log.debug("Executed", operator, "on", edited, "marks")
    end

    if last_edited then
      original_cursor:move(last_edited.start)
    else
      original_cursor:restore()
    end
  else
    -- Callback operator: Collect edits in traversal order,
    -- then apply in reverse order.
    local edits = {}

    local register = Register.new(ctx.register)

    ---@type occurrence.OperatorContext
    local operator_ctx = {
      mode = ctx.mode,
      occurrence = occurrence,
      marks = marks,
      register = register,
    }

    -- Collect edits in traversal order
    for i = 1, #marks do
      local id, mark = unpack(marks[i])
      ---@type occurrence.OperatorCurrent
      local current = {
        index = i,
        id = id,
        range = mark,
        text = vim.api.nvim_buf_get_text(
          occurrence.buffer,
          mark.start.line,
          mark.start.col,
          mark.stop.line,
          mark.stop.col,
          {}
        ),
      }
      local result = operator(current, operator_ctx)

      if result == false then
        -- Operation cancelled
        log.debug("Operation cancelled by callback")
        return false
      elseif result == nil or result == true then
        -- If the `result` is `nil` or `true`,
        -- assume the occurrence has been handled and unmark it
        occurrence.extmarks:unmark(id)
      elseif type(result) == "string" then
        -- Split on newlines if present
        if result:find("\n") then
          result = vim.split(result, "\n", { plain = true })
        else
          result = { result }
        end
        table.insert(edits, { id, mark, result })
      elseif type(result) == "table" then
        -- Replacement operation
        table.insert(edits, { id, mark, result })
      else
        error("Invalid operator result type: " .. type(result))
      end

      if result ~= nil and result ~= false and operator_ctx.register ~= nil then
        if i == 1 then
          operator_ctx.register:clear()
        end
        operator_ctx.register:add(current.text)
      end

      if operator_ctx.register == nil then
        operator_ctx.register = register
      end
    end

    -- Apply edits in reverse order
    for i = #edits, 1, -1 do
      local id, mark, new_text = unpack(edits[i])
      -- Create single undo block for all edits
      if i < #edits then
        vim.cmd("silent! undojoin")
      end
      vim.api.nvim_buf_set_text(
        occurrence.buffer,
        mark.start.line,
        mark.start.col,
        mark.stop.line,
        mark.stop.col,
        new_text
      )
      occurrence.extmarks:unmark(id)
    end

    if operator_ctx.register ~= nil then
      operator_ctx.register:save()
    end

    if #edits > 0 then
      log.debug("Replaced", #edits, "marks")
      local _, first_edit = unpack(edits[1])
      original_cursor:move(first_edit.start)
    else
      original_cursor:restore()
    end
  end
end

-- Register an `:h opfunc` that will apply an operator to occurrences within a range of motion,
-- keeping track of the details of the operation for subsequent `:h single-repeat`.
--
-- If this opfunc is being used to modify a pending operation (`mode` is `"o"`),
-- then the operator will dispose of the occurrence after it is applied. Otherwise,
-- the operator will only dispose of the occurrence if it has no remaining marks.
---@param occurrence occurrence.Occurrence The occurrence to operate on.
---@param operator string | occurrence.OperatorFn The operator to apply (e.g. "d", "y", etc), or a callback function that performs the operation.
---@param ctx occurrence.OpfuncContext The opfunc context.
local function create_opfunc(occurrence, operator, ctx)
  ---@type occurrence.Cursor?
  local cursor = nil
  ---@type occurrence.Range?
  local range = nil
  ---@type fun(type: string)?
  local opfunc = nil
  ---@type string?
  local type = nil
  local win = vim.api.nvim_get_current_win()
  local count = ctx.count or 0

  log.debug("Caching cursor position for opfunc in buffer", occurrence.buffer)
  cursor = Cursor.save()
  CURSOR_CACHE[win] = cursor

  opfunc = function(initial_type)
    -- From :h single-repeat:
    --   > Note that when repeating a command that used a Visual selection,
    --   > the same SIZE of area is used.
    if not type then
      type = initial_type
      log.debug(string.format("opfunc called in mode '%s' with initial type '%s'", ctx.mode, type))
    else
      log.debug(string.format("opfunc called in mode '%s' with original type '%s'", ctx.mode, type))
    end

    -- For visual mode, preserve the size of the original range by moving it to the new position.
    -- For operator-pending/normal mode with motion, recalculate the range at the current position.
    if range and ctx.mode == "v" then
      cursor = cursor or CURSOR_CACHE[win] or Cursor.save()
      if type == "line" then
        range = Range.of_line(cursor.location.line)
      else
        range = range:move(cursor.location)
      end
    else
      -- Recalculate range at current cursor position (don't restore old cursor yet)
      range = Range.of_motion(type)
      cursor = cursor or CURSOR_CACHE[win] or Cursor.save()
    end

    ---@cast occurrence +nil
    if not occurrence or occurrence:is_disposed() then
      -- Get word at current cursor position before restoring
      occurrence = require("occurrence.Occurrence").get()
      local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
      if word == "" then
        log.warn("No word under cursor")
      else
        -- Use of_word with mark=false, then mark the range manually
        occurrence:of_word(false, word)
        for match_range in occurrence:matches(range) do
          occurrence:mark(match_range)
        end
      end
    end

    -- if we are modifying a pending operator, or if count was provided,
    -- use it as a limit on how many occurrences to operate on.
    if ctx.mode == "o" or count > 0 then
      -- From :h single-repeat:
      --   > Without a count, the count of the last change is used.
      --   > If you enter a count, it will replace the last one.
      count = vim.v.count > 0 and vim.v.count or count
    end

    -- if modifying a pending operator with a count, mark only the occurrences
    -- that will be affected by the pending operation.
    if count > 0 and ctx.mode == "o" then
      occurrence:unmark()
      local matches = vim.iter(occurrence:matches(range)):take(count)
      for match_range in matches do
        occurrence:mark(match_range)
      end
    end

    cursor:restore()

    local marks = occurrence.extmarks:collect(range, count > 0 and count or nil)
    log.debug("marks found:" .. #marks)

    if apply_operator(occurrence, operator, marks, ctx) ~= false then
      if ctx.mode == "v" then
        -- Clear visual selection
        feedkeys.change_mode("n", { noflush = true, silent = true })
      end

      cursor = nil

      if occurrence and not occurrence.extmarks:has_any_marks() then
        log.debug("Occurrence has no marks after operation; deactivating")
        occurrence:dispose()
        occurrence = nil ---@diagnostic disable-line: cast-local-type
      end

      -- If running the edits changed `vim.v.operator`, we need to restore it.
      -- NOTE: we do it this way because `vim.v.operator` can only be set internally by nvim.
      if vim.v.operator ~= "g@" then
        log.debug("Restoring operator to g@ for dot-repeat")
        -- set opfunc to a noop so we can get `g@` back into `vim.v.operator` with no side effects.
        _set_opfunc(function() end)
        feedkeys("g@$", { noremap = true })
        -- Restore our original opfunc.
        _set_opfunc(opfunc)
      end

      -- Watch for dot-repeat to cache cursor position prior to repeating the operation.
      watch_dot_repeat()
    end
  end

  _set_opfunc(opfunc)
end

return {
  create_opfunc = create_opfunc,
}
