local Action = require("occurrence.Action")
local Cursor = require("occurrence.Cursor")
local Register = require("occurrence.Register")

local log = require("occurrence.log")

---@module 'occurrence.operators'
local operators = {}

---@class occurrence.OperatorConfigBase
---@field uses_register boolean Whether the operator uses a register.
---@field modifies_text boolean Whether the operator modifies text.

---@class occurrence.VisualFeedkeysOperatorConfig: occurrence.OperatorConfigBase
---@field method 'visual_feedkeys'

---@class occurrence.CommandOperatorConfig: occurrence.OperatorConfigBase
---@field method 'command'

-- Function to generate replacement text for direct_api method.
-- If nil is returned on any n + 1 edits, the first edit replacement value is reused.
---@alias occurrence.ReplacementFunction fun(text?: string | string[], edit: occurrence.Location, index: integer): string | string[] | false | nil

---@class occurrence.DirectApiOperatorConfig: occurrence.OperatorConfigBase
---@field method 'direct_api'
---@field replacement? string | string[] | occurrence.ReplacementFunction Text to replace the occurrence with, or a function that returns the replacement text.

---@alias occurrence.OperatorConfig occurrence.VisualFeedkeysOperatorConfig | occurrence.CommandOperatorConfig | occurrence.DirectApiOperatorConfig

---@param config occurrence.OperatorConfig
local function create_operator(config)
  ---@param occurrence occurrence.Occurrence
  ---@param operator string
  ---@param range? occurrence.Range
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
            replacement = { replacement }
          end

          replacement = replacement or cached_replacement or {}

          if replacement and replacement ~= cached_replacement then
            cached_replacement = replacement
          end

          occurrence:unmark(edit)
          vim.api.nvim_buf_set_text(
            0,
            edit.start.line,
            edit.start.col,
            edit.stop.line,
            edit.stop.col,
            replacement or {}
          )
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
        log.debug("execuing command: ", string.format("%d,%d%s", start_line, stop_line, operator))
        occurrence:unmark(edit)
        vim.cmd(string.format("%d,%d%s", start_line, stop_line, operator))
        edited = edited + 1
      elseif config.method == "visual_feedkeys" then
        log.debug("executing nvim_feedkeys:", operator)
        vim.cmd("normal! v")
        Cursor.move(edit.stop)
        occurrence:unmark(edit)
        vim.api.nvim_feedkeys(operator, "x", true)
        edited = edited + 1
      else
        ---@diagnostic disable-next-line: undefined-field
        error("Unknown operator method: " .. tostring(config.method))
      end
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
---@return occurrence.Action
function operators.get_operator(operator)
  if operators[operator] then
    return operators[operator]
  end

  log.debug("Creating generic fallback for operator:", operator)

  -- Create generic operator with conservative defaults
  local fallback_config = {
    uses_register = false,
    modifies_text = true,
    method = "visual_feedkeys",
  }

  -- Cache the generated operator for future use
  operators[operator] = create_operator(fallback_config)
  return operators[operator]
end

--- Check if an operator is supported
---@param operator string
---@return boolean
function operators.is_supported(operator)
  return operators[operator] ~= nil
end

-- Supported operators

operators.change = create_operator({
  method = "direct_api",
  uses_register = true,
  modifies_text = true,
  replacement = function(text, _, index)
    -- For the first edit, capture user input
    if index == 1 then
      local ok, input = pcall(vim.fn.input, {
        prompt = "Change to: ",
        default = type(text) == "table" and table.concat(text) or (text or ""),
        cancelreturn = false,
      })
      if not ok then
        -- User cancelled with Ctrl-C - return false to abort operation
        return false
      end
      return input
    end
    -- For subsequent edits, return the cached replacement value
    return nil
  end,
})

operators.delete = create_operator({
  method = "direct_api",
  uses_register = true,
  modifies_text = true,
  replacement = {},
})

operators.yank = create_operator({
  method = "direct_api",
  uses_register = true,
  modifies_text = false,
})

operators.indent_left = create_operator({
  method = "command",
  uses_register = false,
  modifies_text = true,
})

operators.indent_right = create_operator({
  method = "command",
  uses_register = false,
  modifies_text = true,
})

-- Default operator mappings :h operator

operators["c"] = operators.change
operators["d"] = operators.delete
operators["y"] = operators.yank
operators["<"] = operators.indent_left
operators[">"] = operators.indent_right

-- TODO:
-- |g@| call function set with the 'operatorfunc' option
-- operators["g@"] = O.opfunc

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

return operators
