---@module 'occurrence.operators'

---@type occurrence.OperatorConfig
local change = {
  desc = "Change marked occurrences",
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
}

---@type occurrence.OperatorConfig
local delete = {
  desc = "Delete marked occurrences",
  method = "direct_api",
  uses_register = true,
  modifies_text = true,
  replacement = {},
}

---@type occurrence.OperatorConfig
local delete_line = {
  desc = "Delete marked occurrences on [count] lines",
  method = "command",
  uses_register = true,
  modifies_text = true,
}

---@type occurrence.OperatorConfig
local delete_to_end_of_line = {
  desc = "Delete marked occurrences to end of line and [count] additional lines",
  method = "command",
  uses_register = true,
  modifies_text = true,
}

---@type occurrence.OperatorConfig
local yank = {
  desc = "Yank marked occurrences",
  method = "direct_api",
  uses_register = true,
  modifies_text = false,
}

---@type occurrence.OperatorConfig
local indent_left = {
  desc = "Indent marked occurrences to the left",
  method = "command",
  uses_register = false,
  modifies_text = true,
}

---@type occurrence.OperatorConfig
local indent_right = {
  desc = "Indent marked occurrences to the right",
  method = "command",
  uses_register = false,
  modifies_text = true,
}

local uppercase = {
  desc = "Make marked occurrences uppercase",
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
}

local lowercase = {
  desc = "Make marked occurrences lowercase",
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
}

local swap_case = {
  desc = "Swap case of marked occurrences",
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
}

local rot13 = {
  desc = "Rot13 encode marked occurrences",
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
}

-- Supported operators
---@enum (key) occurrence.BuiltinOperator
local builtin_operators = {
  change = change,
  delete = delete,
  delete_line = delete_line,
  delete_to_end_of_line = delete_to_end_of_line,
  yank = yank,
  indent_left = indent_left,
  indent_right = indent_right,
  uppercase = uppercase,
  lowercase = lowercase,
  swap_case = swap_case,
  rot13 = rot13,
}
return builtin_operators
