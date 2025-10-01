local Cursor = require("occurrence.Cursor")
local Occurrence = require("occurrence.Occurrence")
local Range = require("occurrence.Range")
local Register = require("occurrence.Register")

local log = require("occurrence.log")
local set_opfunc = require("occurrence.set_opfunc")

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

-- Function to generate replacement text for direct_api method.
-- If nil is returned on any n + 1 edits, the first edit replacement value is reused.
---@alias occurrence.ReplacementFunction fun(text?: string | string[], edit: occurrence.Location, index: integer): string | string[] | false | nil

---@class (exact) occurrence.DirectApiOperator: occurrence.OperatorBase
---@field method "direct_api"
---@field replacement? string | string[] | occurrence.ReplacementFunction

---@param candidate any
---@return boolean
local function is_operator(candidate)
  return type(candidate) == "table"
    and (candidate.method == "visual_feedkeys" or candidate.method == "command" or candidate.method == "direct_api")
end

-- Apply the configured operator to the given occurrence.
---@param occurrence occurrence.Occurrence
---@param config occurrence.OperatorConfig
---@param operator_name? string
---@param range? occurrence.Range
---@param count? integer
---@param register? string
---@param register_type? string
local function apply_operator(occurrence, config, operator_name, range, count, register, register_type)
  operator_name = operator_name or vim.v.operator

  if range then
    log.debug("range:", range)
  end

  local edits = vim.iter(vim.iter(occurrence.extmarks:iter({ range = range })):fold({}, function(acc, _, edit)
    table.insert(acc, edit)
    return acc
  end))

  if count and count > 0 then
    log.debug("count:", count)
    edits = edits:take(count)
  end

  if config.modifies_text then
    log.debug("reversing edits for text modification")
    edits = edits:rev()
  end

  -- Initialize register if needed
  local reg = config.uses_register and Register.new(register, register_type) or nil

  local original_cursor = Cursor.save()

  local edited = 0

  -- Cache for replacement values when using a function
  local cached_replacement = nil

  edits = edits:totable()

  log.debug("edits found:" .. #edits)

  -- Apply operation to all occurrences
  for i, edit in ipairs(edits) do
    -- Create single undo block for all edits
    if config.modifies_text and edited > 0 then
      vim.cmd("silent! undojoin")
    end

    Cursor.move(edit.start)

    -- Get text for register/processing
    local text = nil
    if config.uses_register or config.modifies_text or config.method == "interactive" then
      text = vim.api.nvim_buf_get_text(0, edit.start.line, edit.start.col, edit.stop.line, edit.stop.col, {})
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
          replacement = config.replacement(text, edit, i)
        else
          replacement = config.replacement
        end

        if i == 1 and replacement == false then
          log.debug("Operation cancelled by user")
          original_cursor:restore()
          return
        end

        if type(replacement) == "string" then
          ---@cast replacement string[]
          replacement = { replacement }
        end

        replacement = replacement or cached_replacement or {}

        if replacement and replacement ~= cached_replacement then
          cached_replacement = replacement
        end

        occurrence:unmark(edit)
        vim.api.nvim_buf_set_text(0, edit.start.line, edit.start.col, edit.stop.line, edit.stop.col, replacement or {})
        edited = edited + 1
      else
        -- NOTE: at this point, "direct_api" that does not modify text is a no-op.
        -- If it "uses_register", the text has already been yanked to the register.
        -- Maybe we will want to support processing the text in some way in the future,
        -- but that likely means rethinking "direct_api" with a replacement function as
        -- something more general.
        occurrence:unmark(edit)
        edited = edited + 1
      end
    elseif config.method == "command" then
      local start_line, stop_line = edit.start.line + 1, edit.stop.line + 1
      log.debug("execuing command: ", string.format("%d,%d%s", start_line, stop_line, operator_name))
      occurrence:unmark(edit)
      vim.cmd(string.format("%d,%d%s", start_line, stop_line, operator_name))
      edited = edited + 1
    elseif config.method == "visual_feedkeys" then
      log.debug("executing nvim_feedkeys:", operator_name)
      vim.api.nvim_feedkeys("v", "nx", true)
      Cursor.move(edit.stop)
      occurrence:unmark(edit)
      vim.api.nvim_feedkeys(operator_name, "nx", true)
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

---@param operator_key string
---@param config occurrence.OperatorConfig
---@return function
local function create_operator(operator_key, config)
  return function()
    local occurrence = Occurrence.get()
    local count, register = vim.v.count, vim.v.register

    -- If in visual mode, we should apply the operator directly to the selection
    -- instead of entering operator-pending mode.
    if vim.fn.mode():match("[vV]") then
      log.debug("In visual mode; applying operator directly to selection")
      local selection_range = Range.of_selection()
      if not selection_range then
        log.error("No visual selection found for operator", operator_key)
        return
      end

      -- Clear visual selection
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)

      -- Run the operator
      apply_operator(occurrence, config, operator_key, selection_range, count, register, nil)

      -- Move the cursor back to the start of the selection.
      -- This seems to be what nvim does after a visual operation?
      Cursor.move(selection_range.start)

      if not occurrence.extmarks:has_any() then
        log.debug("Occurrence has no marks after operation; deactivating")
        occurrence:dispose()
      end
    -- Otherwise, set up for operator-pending mode.
    else
      set_opfunc({
        operator = operator_key,
        occurrence = occurrence,
        count = count,
        register = register,
      }, function(state)
        state.count = vim.v.count > 0 and vim.v.count or state.count
        state.register = vim.v.register

        apply_operator(
          state.occurrence,
          config,
          state.operator,
          Range.of_motion(state.type),
          state.count,
          state.register,
          state.type
        )

        if not occurrence.extmarks:has_any() then
          log.debug("Occurrence has no marks after operation; deactivating")
          occurrence:dispose()
        end
      end)

      -- send g@ to trigger custom opfunc
      return "g@"
    end
  end
end

return {
  new = create_operator,
  is = is_operator,
  apply = apply_operator,
}
