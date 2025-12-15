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

-- Expand marks in-place to include surrounding whitespace.
-- This simulates Vim's "around" text object behavior (e.g., `aw` vs `iw`).
-- Rules:
--   1. If there's whitespace after the word, include it (preferred)
--   2. Otherwise, if there's whitespace before the word, include it
--   3. This ensures we include one "side" of whitespace
---@param marks [integer, occurrence.Range][] The marks to expand.
local function expand_around(marks)
  local original_cursor = Cursor.save()
  -- expand all marks to include surrounding whitespace
  for i = 1, #marks do
    local id, mark = unpack(marks[i])
    original_cursor:move(mark.stop)
    local col = mark.stop:to_pos()[2]
    -- check if next char is whitespace
    if vim.fn.getline("."):sub(col, col):match("%s") then
      -- search forward for next non-whitespace char
      local new_stop = Location.from_pos(vim.fn.searchpos([[\S]], "nWc"))
      if new_stop and new_stop > mark.stop then
        local new_mark = Range.new(mark.start, new_stop)
        log.trace("Expanded mark", id, "from", mark, "to", new_mark)
        marks[i] = { id, new_mark }
      end
    else
      -- if no forward whitespace, search backward for previous whitespace
      original_cursor:move(mark.start)
      ---@diagnostic disable-next-line: redefined-local
      local col = mark.start:to_pos()[2] - 1
      if col > 0 and vim.fn.getline("."):sub(col, col):match("%s") then
        local new_start = Location.from_pos(vim.fn.searchpos([[\s]], "bnWe"))
        if new_start and new_start < mark.start then
          local new_mark = Range.new(new_start, mark.stop)
          log.trace("Expanded mark", id, "from", mark, "to", new_mark)
          marks[i] = { id, new_mark }
        end
      end
    end
  end
  original_cursor:restore()
end

-- A queue for managing batched operator execution.
---@class occurrence.OperatorQueue
---@field operator occurrence.OperatorFn
---@field ctx occurrence.OperatorContext
---@field register occurrence.Register?
---@field items occurrence.OperatorCurrent[]
---@field head integer
---@field tail integer
---@field first_run boolean
local OperatorQueue = {}

---@param item occurrence.OperatorCurrent
function OperatorQueue:enqueue(item)
  self.tail = self.tail + 1
  self.items[self.tail] = item
end

---@param batch_size number
---@return nil | fun(done: fun(current: occurrence.OperatorCurrent, result: string | string[] | boolean | nil))[]
function OperatorQueue:dequeue(batch_size)
  if self.head > self.tail then
    return nil
  end

  local batch = {}

  ---@param current occurrence.OperatorCurrent
  ---@param result string | string[] | boolean | nil
  ---@param done fun(current: occurrence.OperatorCurrent, result: string | string[] | boolean | nil)
  local function on_result(current, result, done)
    if self.first_run then
      if result ~= nil and result ~= false and self.ctx.register ~= nil then
        self.ctx.register:clear()
      end
      self.first_run = false
    end

    if result ~= nil and result ~= false and self.ctx.register ~= nil then
      self.ctx.register:add(current.text)
    end

    if self.ctx.register == nil then
      self.ctx.register = self.register
    end

    done(current, result)
  end

  for _ = 1, batch_size do
    if self.head > self.tail then
      return batch
    end

    local current = self.items[self.head]
    self.items[self.head] = nil
    self.head = self.head + 1

    table.insert(batch, function(cb)
      local result = self.operator(current, self.ctx)
      if type(result) == "function" then
        result(function(res)
          on_result(current, res, cb)
        end)
      else
        on_result(current, result, cb)
      end
    end)
  end

  return batch
end

---@param operator occurrence.OperatorFn
---@param ctx occurrence.OperatorContext
local function create_operator_queue(operator, ctx)
  return setmetatable({
    operator = operator,
    register = ctx.register,
    ctx = ctx,
    items = {},
    head = 1,
    tail = 0,
    first_run = true,
  }, { __index = OperatorQueue })
end

-- A list of edits to apply to the occurrence buffer.
-- Edits are applied in reverse order to avoid changing the location of subsequent edits.
---@class occurrence.EditList
---@field occurrence occurrence.Occurrence
---@field ctx occurrence.OperatorContext
---@field cursor occurrence.Cursor
---@field edits? [integer, occurrence.Range, string[]][]
local EditList = {}

---@param current occurrence.OperatorCurrent
---@param new_text string[]
function EditList:add(current, new_text)
  if not self.edits then
    self.edits = {}
  end
  table.insert(self.edits, current.index, { current.id, current.range, new_text })
  log.trace("EditList:add called for index", current.index, "total edits:", #self.edits)
end

function EditList:apply()
  local edits = self.edits or {}
  self.edits = nil

  log.debug("EditList:apply called with", #edits, "edits")

  -- Apply edits in reverse order
  for i = #edits, 1, -1 do
    local id, mark, new_text = unpack(edits[i])
    -- Create single undo block for all edits
    if i < #edits then
      vim.cmd("silent! undojoin")
    end
    vim.api.nvim_buf_set_text(
      self.occurrence.buffer,
      mark.start.line,
      mark.start.col,
      mark.stop.line,
      mark.stop.col,
      new_text
    )
    self.occurrence.extmarks:unmark(id)
  end

  if self.ctx.register ~= nil then
    self.ctx.register:save()
  end

  if #edits > 0 then
    log.debug("Replaced", #edits, "marks")
    local _, first_edit = unpack(edits[1])
    self.cursor:move(first_edit.start)
  else
    self.cursor:restore()
  end
end

---@param occurrence occurrence.Occurrence
---@param ctx occurrence.OperatorContext
local function create_edit_list(occurrence, ctx)
  return setmetatable({
    occurrence = occurrence,
    ctx = ctx,
    cursor = Cursor.save(),
  }, { __index = EditList })
end

-- Apply an operator string (e.g. `"d"`, `"y"`, etc) to a visual selection of each mark.
---@param operator string The operator string (e.g. "d", "y", etc).
---@param ctx occurrence.OperatorContext The operator context.
---@param done fun() Callback when operations are complete.
local function apply_operator_string(operator, ctx, done)
  local occurrence = ctx.occurrence
  local marks = ctx.marks
  local original_cursor = Cursor.save()

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

  done()
end

---@param operator occurrence.OperatorFn
---@param ctx occurrence.OperatorContext The operator context.
---@param batch_size number Maximum concurrent operations.
---@param done fun(result: boolean?) Callback when all operations are complete or cancelled.
local function apply_operator_fn(operator, ctx, batch_size, done)
  local occurrence = ctx.occurrence
  local marks = ctx.marks
  local edits = create_edit_list(occurrence, ctx)
  local operations = create_operator_queue(operator, ctx)

  for i = 1, #marks do
    local id, mark = unpack(marks[i])
    operations:enqueue({
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
    })
  end

  local next_batch, execute_next_batch
  execute_next_batch = function()
    next_batch = operations:dequeue(batch_size)
    if next_batch and #next_batch > 0 then
      local remaining = #next_batch
      local cancelled = false
      for _, operation in ipairs(next_batch) do
        operation(function(current, result)
          remaining = remaining - 1
          log.trace("Operation callback called for index", current.index, "remaining:", remaining)
          if cancelled or result == false then
            cancelled = true
          else
            if result == nil or result == true then
              -- If the `result` is `nil` or `true`,
              -- assume the occurrence has been handled and unmark it
              occurrence.extmarks:unmark(current.id)
            elseif type(result) == "string" then
              -- Split on newlines if present
              if result:find("\n") then
                result = vim.split(result, "\n", { plain = true })
              else
                result = { result }
              end
              edits:add(current, result)
            elseif type(result) == "table" then
              edits:add(current, result)
            else
              error("Invalid operator result type: " .. type(result))
            end
          end

          if remaining <= 0 then
            if cancelled then
              log.trace("Operation cancelled")
              done(false)
            else
              execute_next_batch()
            end
          end
        end)
      end
    else
      edits:apply()
      done()
    end
  end

  execute_next_batch()
end

-- Register an `:h opfunc` that will apply an operator to occurrences within a range of motion,
-- keeping track of the details of the operation for subsequent `:h single-repeat`.
--
-- If this opfunc is being used to modify a pending operation (`mode` is `"o"`),
-- then the operator will dispose of the occurrence after it is applied. Otherwise,
-- the operator will only dispose of the occurrence if it has no remaining marks.
---@param occurrence occurrence.Occurrence The occurrence to operate on.
---@param operator string | occurrence.OperatorFn | occurrence.OperatorConfig The operator to apply (e.g. "d", "y", etc), or a callback function that performs the operation, or an operator config table.
---@param ctx occurrence.OpfuncContext The opfunc context.
local function create_opfunc(occurrence, operator, ctx)
  ---@type occurrence.Cursor?
  local cursor = nil
  ---@type occurrence.Range?
  local range = nil
  ---@type fun(type: string)?
  local opfunc = nil
  ---@type string?
  local motion_type = nil
  local win = vim.api.nvim_get_current_win()
  local count = ctx.count or 0
  local before_hook = nil
  local batch_size = 10

  if type(operator) == "table" then
    before_hook = operator.before
    batch_size = operator.batch_size or batch_size
    operator = operator.operator
    ---@cast operator -occurrence.OperatorConfig
  end

  log.debug("Caching cursor position for opfunc in buffer", occurrence.buffer)
  cursor = Cursor.save()
  CURSOR_CACHE[win] = cursor

  opfunc = function(initial_type)
    -- From :h single-repeat:
    --   > Note that when repeating a command that used a Visual selection,
    --   > the same SIZE of area is used.
    if not motion_type then
      motion_type = initial_type
      log.debug(string.format("opfunc called in mode '%s' with initial type '%s'", ctx.mode, motion_type))
    else
      log.debug(string.format("opfunc called in mode '%s' with original type '%s'", ctx.mode, motion_type))
    end

    -- For visual mode, preserve the size of the original range by moving it to the new position.
    -- For operator-pending/normal mode with motion, recalculate the range at the current position.
    if range and ctx.mode == "v" then
      cursor = cursor or CURSOR_CACHE[win] or Cursor.save()
      if motion_type == "line" then
        range = Range.of_line(cursor.location.line)
      else
        range = range:move(cursor.location)
      end
    else
      -- Recalculate range at current cursor position (don't restore old cursor yet)
      range = Range.of_motion(motion_type)
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

    log.debug("Collecting marks for operation in range", range, "with count", count)
    local marks = occurrence.extmarks:collect(range, count > 0 and count or nil)
    log.debug("marks found:" .. #marks)

    if ctx.inner ~= true then
      expand_around(marks)
    end

    ---@param result boolean?
    local function on_done(result)
      if result ~= false then
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

    ---@type occurrence.OperatorContext
    local operator_ctx = {
      mode = ctx.mode,
      occurrence = occurrence,
      marks = marks,
      register = Register.new(ctx.register),
    }

    local function apply_operator()
      if type(operator) == "string" then
        apply_operator_string(operator, operator_ctx, on_done)
      else
        apply_operator_fn(operator, operator_ctx, batch_size, on_done)
      end
    end

    if type(before_hook) == "function" then
      local before_result = before_hook(marks, operator_ctx)
      if before_result == false then
        log.debug("Operation cancelled by before hook")
        on_done(false)
      elseif type(before_result) == "function" then
        before_result(function(ok)
          if ok == false then
            log.debug("Operation cancelled by before hook async result")
            on_done(false)
          else
            apply_operator()
          end
        end)
      else
        apply_operator()
      end
    else
      apply_operator()
    end
  end

  _set_opfunc(opfunc)
end

return {
  create_opfunc = create_opfunc,
}
