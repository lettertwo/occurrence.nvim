local Action = require("occurrence.Action")
local Cursor = require("occurrence.Cursor")
local Register = require("occurrence.Register")

local log = require("occurrence.log")

---@class OccurrenceOperators
local O = {}

---@class OperatorConfigBase
---@field uses_register boolean Whether the operator uses a register.
---@field modifies_text boolean Whether the operator modifies text.

---@class VisualFeedkeysOperatorConfig: OperatorConfigBase
---@field method 'visual_feedkeys'

---@class CommandOperatorConfig: OperatorConfigBase
---@field method 'command'

-- Function to generate replacement text for direct_api method.
-- If nil is returned on any n + 1 edits, the first edit replacement value is reused.
---@alias ReplacementFunction fun(text?: string | string[], edit: Location, index: integer): string | string[] | nil

---@class DirectApiOperatorConfig: OperatorConfigBase
---@field method 'direct_api'
---@field replacement? string | string[] | ReplacementFunction Text to replace the occurrence with, or a function that returns the replacement text.

---@alias OperatorConfig VisualFeedkeysOperatorConfig | CommandOperatorConfig | DirectApiOperatorConfig

---@param config OperatorConfig
local function create_operator(config)
  ---@param occurrence Occurrence
  ---@param operator string
  ---@param range? Range
  ---@param count? integer
  ---@param register? string
  ---@param register_type? string
  return Action.new(function(occurrence, operator, range, count, register, register_type)
    if range then
      log.debug("range:", range)
    end

    local edits = vim.iter(vim.iter(occurrence:marks({ range = range })):fold({}, function(acc, _, edit)
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

    local original_cursor = Cursor:save()

    local edited = 0

    -- Cache for replacement values when using a function
    local cached_replacement = nil

    -- Collect edits into a table and unmark all occurrences before applying operation
    edits = edits:totable()
    for o in occurrence:marks() do
      occurrence:unmark(o)
    end

    log.debug("edits found:" .. #edits)

    -- Apply operation to all occurrences
    for i, edit in ipairs(edits) do
      log.debug(edit)

      -- Create single undo block for all edits
      if config.modifies_text and edited > 0 then
        vim.cmd("silent! undojoin")
      end

      Cursor:move(edit.start)

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
          local replacement = config.replacement
          if type(replacement) == "function" then
            replacement = replacement(text, edit, i) or cached_replacement
            -- cache initial replacement for re-use on edits that don't provide new replacement values,
            -- e.g., when doing a change oeration.
            if edited == 0 then
              cached_replacement = replacement
            end
          end

          if type(replacement) == "string" then
            replacement = { replacement }
          end

          vim.api.nvim_buf_set_text(
            0,
            edit.start.line,
            edit.start.col,
            edit.stop.line,
            edit.stop.col,
            replacement or {}
          )
        end
      elseif config.method == "command" then
        local start_line, stop_line = edit.start.line + 1, edit.stop.line + 1
        log.debug("execuing command: ", string.format("%d,%d%s", start_line, stop_line, operator))
        vim.cmd(string.format("%d,%d%s", start_line, stop_line, operator))
      elseif config.method == "visual_feedkeys" then
        log.debug("executing nvim_feedkeys:", operator)
        vim.cmd("normal! v")
        Cursor:move(edit.stop)
        vim.api.nvim_feedkeys(operator, "x", true)
      else
        ---@diagnostic disable-next-line: undefined-field
        error("Unknown operator method: " .. tostring(config.method))
      end
      edited = edited + 1
    end

    if edited == 0 then
      log.error("No occurrences to apply operator", operator)
      return
    end

    -- Save register contents
    if reg then
      reg:save()
    end

    original_cursor:restore()
    log.debug("Applied operator", operator, "to", edited, "occurrences. Method: ", config.method)
  end)
end

--- Generic fallback for unknown operators
---@param operator string
---@return Action
function O.get_operator(operator)
  if O[operator] then
    return O[operator]
  end

  log.debug("Creating generic fallback for operator:", operator)

  -- Create generic operator with conservative defaults
  local fallback_config = {
    uses_register = false,
    modifies_text = true,
    method = "visual_feedkeys",
  }

  -- Cache the generated operator for future use
  O[operator] = create_operator(fallback_config)
  return O[operator]
end

--- Check if an operator is supported
---@param operator string
---@return boolean
function O.is_supported(operator)
  return O[operator] ~= nil
end

-- Supported operators

O.change = create_operator({
  method = "direct_api",
  uses_register = true,
  modifies_text = true,
  replacement = function(_, edit, index)
    -- For the first edit, capture user input
    if index == 1 then
      local input = vim.fn.input("Change to: ")
      return input
    end
    -- For subsequent edits, return the cached replacement value
    return nil
  end,
})

O.delete = create_operator({
  method = "direct_api",
  uses_register = true,
  modifies_text = true,
  replacement = {},
})

O.yank = create_operator({
  method = "direct_api",
  uses_register = true,
  modifies_text = false,
})

O.indent_left = create_operator({
  method = "command",
  uses_register = false,
  modifies_text = true,
})

O.indent_right = create_operator({
  method = "command",
  uses_register = false,
  modifies_text = true,
})

-- Default operator mappings :h operator

O["c"] = O.change
O["d"] = O.delete
O["y"] = O.yank
O["<"] = O.indent_left
O[">"] = O.indent_right

-- TODO:
-- |g@| call function set with the 'operatorfunc' option
-- O["g@"] = O.opfunc

-- The rest of these are handled by the generic fallback

-- |~| swap case (only if 'tildeop' is set)
-- |g~| swap case
-- |gu| make lowercase
-- |gU| make uppercase
-- |!| filter through an external program
-- |=| filter through 'equalprg' or C-indenting if empty
-- |gq| text formatting
-- |gw| text formatting with no cursor movement
-- |g?| ROT13 encoding
-- |zf| define a fold

return O
