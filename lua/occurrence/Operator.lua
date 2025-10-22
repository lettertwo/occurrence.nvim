local Cursor = require("occurrence.Cursor")
local Range = require("occurrence.Range")
local Register = require("occurrence.Register")

local feedkeys = require("occurrence.feedkeys")
local log = require("occurrence.log")

---@module "occurrence.Operator"

---@alias occurrence.OperatorMethod "visual_feedkeys" | "command" | "direct_api"

---@alias occurrence.OperatorConfig occurrence.VisualFeedkeysOperatorConfig | occurrence.CommandOperatorConfig | occurrence.DirectApiOperatorConfig

-- An action that will be used as a preset keymap or as an operator-pending keymap.
---@class (exact) occurrence.OperatorConfigBase
---@field desc? string
---@field uses_register boolean Whether the operator uses a register.
---@field modifies_text boolean Whether the operator modifies text.

---@class (exact) occurrence.VisualFeedkeysOperatorConfig: occurrence.OperatorConfigBase
---@field method "visual_feedkeys"

---@class (exact) occurrence.CommandOperatorConfig: occurrence.OperatorConfigBase
---@field method "command"

---@class (exact) occurrence.DirectApiOperatorConfig: occurrence.OperatorConfigBase
---@field method "direct_api"
---@field replacement? string | string[] | occurrence.ReplacementFunction Text to replace the occurrence with, or a function that returns the replacement text.

-- Function to be used as a callback for an operator action.
-- It will receive the following arguments:
-- - The `occurrence` for the current buffer.
-- - The `operator_name` (e.g. "d", "y", etc). If `nil`, it will be taken from `vim.v.operator`.
-- - The `range` of motion (e.g. "daw", "y$", etc). If `nil`, the full buffer range will be used.
-- - The `count` (e.g. "2d", "3y", etc). If `nil`, all occurrences in the `range` will be used.
-- - The `register` (e.g. '"*d', '"ay', etc). If `nil`, the default register will be used.
-- - The `register_type` (e.g. "v", "V", etc). If `nil`, it will be inferred from the text yanked to the register.
---@alias occurrence.OperatorCallback fun(occurrence: occurrence.Occurrence, operator_name?: string, range?: occurrence.Range, count?: integer, register?: string, register_type?: string): nil

---@class (exact) occurrence.OperatorBase
---@field desc string
---@field callback occurrence.OperatorCallback
---@field uses_register boolean
---@field modifies_text boolean

---@class (exact) occurrence.VisualFeedkeysOperator: occurrence.OperatorBase
---@field method "visual_feedkeys"

---@class (exact) occurrence.CommandOperator: occurrence.OperatorBase
---@field method "command"

---@class occurrence.ReplacementContext
---@field location occurrence.Location
---@field total_count integer
---@field register? string
---@field register_type? string

-- Function to generate replacement text for direct_api method.
-- If nil is returned on any n + 1 edits, the first edit replacement value is reused.
---@alias occurrence.ReplacementFunction fun(text?: string | string[], ctx: occurrence.ReplacementContext, index: integer): string | string[] | false | nil

---@class (exact) occurrence.DirectApiOperator: occurrence.OperatorBase
---@field method "direct_api"
---@field replacement? string | string[] | occurrence.ReplacementFunction

---@param candidate any
---@return boolean
local function is_operator(candidate)
  return type(candidate) == "table"
    and (candidate.method == "visual_feedkeys" or candidate.method == "command" or candidate.method == "direct_api")
end

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

-- Apply the configured operator to the given occurrence.
---@param occurrence occurrence.Occurrence The occurrence to operate on.
---@param config occurrence.OperatorConfig The configuration for the operator. One of:
--   - `method = visual_feedkeys`: The operator will be applied in visual mode using `nvim.api.nvim_feedkeys`.
--   - `method = command`: The operator will be applied using a command (e.g. `:d`, `:y`, etc).
--   - `method = direct_api`: The operator will be applied directly using the Neovim API.
---@param operator_name? string The name of the operator (e.g. "d", "y", etc). If `nil`, it will be taken from `vim.v.operator`.
---@param range? occurrence.Range The range of motion (e.g. "daw", "y$", etc). If `nil`, the full buffer range will be used.
---@param count? integer The count of occurrences in the range to operate on. If `nil` or `0`, all occurrences in the range will be touched.
---@param register? string The register (e.g. '"*d', '"ay', etc). If `nil`, the default register will be used.
---@param register_type? string The type of the register (e.g. "v", "V", etc). If `nil`, it will be inferred from the text yanked to the register.
local function apply_operator(occurrence, config, operator_name, range, count, register, register_type)
  operator_name = operator_name or vim.v.operator

  if range then
    log.debug("range:", range)
  end

  local marks =
    vim.iter(vim.iter(occurrence.extmarks:iter_marks({ range = range })):fold({}, function(acc, origin, edit)
      table.insert(acc, { origin, edit })
      return acc
    end))

  if count and count > 0 then
    log.debug("count:", count)
    marks = marks:take(count)
  end

  if config.modifies_text then
    log.debug("reversing edits for text modification")
    marks = marks:rev()
  end

  -- Initialize register if needed
  local reg = config.uses_register and Register.new(register, register_type) or nil

  local original_cursor = Cursor.save()

  local edited = 0

  -- Cache for replacement values when using a function
  local cached_replacement = nil

  marks = marks:totable()

  log.debug("edits found:" .. #marks)

  -- Apply operation to all occurrences
  for i = 1, #marks do
    local mark, edit = unpack(marks[i])
    -- Create single undo block for all edits
    if config.modifies_text and edited > 0 then
      vim.cmd("silent! undojoin")
    end

    Cursor.move(edit.start)

    -- Get text for register/processing
    local text = nil
    if config.uses_register or config.modifies_text or config.method == "direct_api" then
      text =
        vim.api.nvim_buf_get_text(occurrence.buffer, edit.start.line, edit.start.col, edit.stop.line, edit.stop.col, {})
    end

    -- Save to register if needed
    if reg ~= nil and text ~= nil then
      reg:add(text)
    end

    -- Apply the operation based on method
    if config.method == "direct_api" then
      if config.modifies_text then
        local replacement
        if type(config.replacement) == "function" then
          local ctx = {
            location = edit,
            register = register,
            register_type = register_type,
            total_count = #marks,
          }
          replacement = config.replacement(text, ctx, i)
        else
          replacement = config.replacement
        end

        if i == 1 and replacement == false then
          log.debug("Operation cancelled by user")
          original_cursor:restore()
          return
        end

        if type(replacement) == "string" then
          -- Split on newlines if present (e.g., from multi-line register content)
          if replacement:find("\n") then
            replacement = vim.split(replacement, "\n", { plain = true })
          else
            replacement = { replacement }
          end
        end

        replacement = replacement or cached_replacement or {}
        ---@cast replacement string[]

        if replacement and replacement ~= cached_replacement then
          cached_replacement = replacement
        end

        occurrence.extmarks:unmark(mark)
        vim.api.nvim_buf_set_text(
          occurrence.buffer,
          edit.start.line,
          edit.start.col,
          edit.stop.line,
          edit.stop.col,
          replacement
        )
        edited = edited + 1
      else
        -- NOTE: at this point, "direct_api" that does not modify text is a no-op.
        -- If it "uses_register", the text has already been yanked to the register.
        -- Maybe we will want to support processing the text in some way in the future,
        -- but that likely means rethinking "direct_api" with a replacement function as
        -- something more general.
        occurrence.extmarks:unmark(mark)
        edited = edited + 1
      end
    elseif config.method == "command" then
      local start_line, stop_line = edit.start.line + 1, edit.stop.line + 1
      log.debug("execuing command: ", string.format("%d,%d%s", start_line, stop_line, operator_name))
      occurrence.extmarks:unmark(mark)
      vim.cmd(string.format("%d,%d%s", start_line, stop_line, operator_name))
      edited = edited + 1
    elseif config.method == "visual_feedkeys" then
      -- Clear any visual selection before (re-)entering visual mode
      feedkeys.change_mode("v", { force = true, silent = true })
      Cursor.move(edit.stop)
      occurrence.extmarks:unmark(mark)
      log.debug("executing nvim_feedkeys:", operator_name)
      feedkeys(operator_name, { noremap = true })
      edited = edited + 1
    else
      ---@diagnostic disable-next-line: undefined-field
      error("Unknown operator method: " .. tostring(config.method))
    end
  end

  if edited == 0 then
    log.debug("No occurrences to apply operator", operator_name)
    return
  end

  -- Save register contents
  if reg then
    reg:save()
  end

  original_cursor:restore()
  log.debug("Applied operator", operator_name, "to", edited, "occurrences. Method: ", config.method)
end

-- Register an `:h opfunc` that will apply an operator to occurrences within a range of motion,
-- keeping track of the details of the operation for subesquent `:h single-repeat`.
--
-- If this opfunc is being used to modify a pending operation (`mode` is `"o"`),
-- then the operator will dispose of the occurrence after it is applied. Otherwise,
-- the operator will only dispose of the occurrence if it has no remaining marks.
---@param mode 'n' | 'v' | 'o' The mode from which the operator is being triggered.
---@param occurrence occurrence.Occurrence The occurrence to operate on.
---@param config occurrence.OperatorConfig The configuration for the operator. One of:
--   - `method = visual_feedkeys`: The operator will be applied in visual mode using `nvim.api.nvim_feedkeys`.
--   - `method = command`: The operator will be applied using a command (e.g. `:d`, `:y`, etc).
--   - `method = direct_api`: The operator will be applied directly using the Neovim API.
---@param operator_name string The name of the operator (e.g. "d", "y", etc). If `nil`, it will be taken from `vim.v.operator`.
---@param count integer The count (e.g. "2d", "3y", etc). Only used if the opfunc is replacing a pending operator.
---@param register string The register (e.g. '"*d', '"ay', etc). If `nil`, the default register will be used.
local function create_opfunc(mode, occurrence, config, operator_name, count, register)
  ---@type occurrence.Cursor?
  local cursor = nil
  ---@type occurrence.Range?
  local range = nil
  ---@type fun(type: string)?
  local opfunc = nil
  ---@type string?
  local type = nil
  local win = vim.api.nvim_get_current_win()

  log.debug("Caching cursor position for opfunc in buffer", occurrence.buffer)
  cursor = Cursor.save()
  CURSOR_CACHE[win] = cursor

  opfunc = function(initial_type)
    -- From :h single-repeat:
    --   > Note that when repeating a command that used a Visual selection,
    --   > the same SIZE of area is used.
    type = type or initial_type

    -- For visual mode, preserve the size of the original range by moving it to the new position.
    -- For operator-pending/normal mode with motion, recalculate the range at the current position.
    if range and mode == "v" then
      cursor = cursor or CURSOR_CACHE[win] or Cursor.save()
      range = range:move(cursor.location)
    else
      -- Recalculate range at current cursor position (don't restore old cursor yet)
      range = Range.of_motion(type)
      cursor = cursor or CURSOR_CACHE[win] or Cursor.save()
    end

    ---@cast occurrence +nil
    if not occurrence then
      -- Get word at current cursor position before restoring
      occurrence = require("occurrence.Occurrence").get()
      local word = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
      if word == "" then
        log.warn("No word under cursor")
      else
        occurrence:add_pattern(word, "word")
      end
    end

    -- From :h single-repeat:
    --   > Without a count, the count of the last change is used.
    --   > If you enter a count, it will replace the last one.
    count = vim.v.count > 0 and vim.v.count or count
    -- if we are modifying a pending operator, then consume the count
    -- as a limit on how many occurrences to operate on.
    if mode == "o" and count and count > 0 then
      occurrence:unmark()
      local matches = vim.iter(occurrence:matches(range))
      matches = matches:take(count)
      for match_range in matches do
        occurrence:mark(match_range)
      end
    end

    cursor:restore()

    if
      apply_operator(
        occurrence,
        config,
        operator_name,
        range,
        -- NOTE: if we are replacing a pending operator, we've already consumed count
        -- while selecting occurrences, so we pass `0` to indicate that the operator should not be limited by count.
        mode ~= "o" and count or 0,
        register,
        type
      ) ~= false
    then
      if mode == "v" then
        -- Clear visual selection
        feedkeys.change_mode("n", { noflush = true, silent = true })
        if cursor and range then
          -- Move the cursor back to the start of the selection.
          -- This seems to be what nvim does after a visual operation?
          cursor:move(range.start)
        end
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

---@param operator_key string
---@param operator_config occurrence.OperatorConfig
---@return fun(occurrence: occurrence.Occurrence?): "g@"
local function create_operator(operator_key, operator_config)
  return function(occurrence)
    occurrence = occurrence or require("occurrence.Occurrence").get()
    local count, register = vim.v.count, vim.v.register
    local mode = vim.fn.mode():match("[vV]") and "v" or "n"
    create_opfunc(mode, occurrence, operator_config, operator_key, count, register)
    -- send g@ to trigger custom opfunc
    return "g@"
  end
end

return {
  new = create_operator,
  is = is_operator,
  apply = apply_operator,
  create_opfunc = create_opfunc,
}
