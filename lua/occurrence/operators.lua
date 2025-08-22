local Action = require("occurrence.Action")
local Cursor = require("occurrence.Cursor")
local Register = require("occurrence.Register")

local log = require("occurrence.log")

-- Find edit locations for marked occurrences within the given range.
-- If `count` is given, limits the number of occurrences to find.
---@param occurrence Occurrence
---@param range? Range
---@param count? integer
---@return Iter<Range>?
local function find_edits(occurrence, range, count)
  local edits = {}
  local marks = vim.iter(occurrence:marks({ range = range }))
  if count and count > 1 then
    marks = marks:take(count)
  end
  for _, mark_range in marks do
    table.insert(edits, mark_range)
  end
  if #edits > 0 then
    return vim.iter(edits)
  end
  return nil
end

-- Operator actions
-- TODO: support individual config for operators.
-- |~|	~	swap case (only if 'tildeop' is set)
-- |g~|	g~	swap case
-- |gu|	gu	make lowercase
-- |gU|	gU	make uppercase
-- |!|	!	filter through an external program
-- |=|	=	filter through 'equalprg' or C-indenting if empty
-- |gq|	gq	text formatting
-- |gw|	gw	text formatting with no cursor movement
-- |g?|	g?	ROT13 encoding
-- |>|	>	shift right
-- |<|	<	shift left
-- |zf|	zf	define a fold
-- |g@|	g@	call function set with the 'operatorfunc' option

---@class OccurrenceOperators
local O = {}

-- Change marked occurrences.
---@param occurrence Occurrence
---@param range? Range
---@param count? integer
---@param register? string
---@param register_type? string
O.change = Action.new(function(occurrence, range, count, register, register_type)
  local reg = Register.new(register, register_type)
  local edits = find_edits(occurrence, range, count)
  if edits then
    local input = vim.fn.input("Change to: ")
    if input ~= "" then
      for edit in edits:rev() do
        local start_line, start_col, stop_line, stop_col = unpack(edit)
        Cursor:move(edit.start)
        reg:add(vim.api.nvim_buf_get_text(0, start_line, start_col, stop_line, stop_col, {}))
        vim.api.nvim_buf_set_text(0, start_line, start_col, stop_line, stop_col, {})
        vim.api.nvim_buf_set_text(0, start_line, start_col, start_line, start_col, { input })
      end
      reg:save()
    end
  else
    log.debug("No marked occurrences found in motion")
  end
end)

-- Delete marked occurrences.
---@param occurrence Occurrence
---@param range? Range
---@param count? integer
---@param register? string
---@param register_type? string
O.delete = Action.new(function(occurrence, range, count, register, register_type)
  local reg = Register.new(register, register_type)
  local edits = find_edits(occurrence, range, count)
  if edits then
    for edit in edits:rev() do
      local start_line, start_col, stop_line, stop_col = unpack(edit)
      Cursor:move(edit.start)
      reg:add(vim.api.nvim_buf_get_text(0, start_line, start_col, stop_line, stop_col, {}))
      vim.api.nvim_buf_set_text(0, start_line, start_col, stop_line, stop_col, {})
    end
    reg:save()
  else
    log.debug("No marked occurrences found in motion")
  end
end)

-- Yank marked occurrences.
---@param occurrence Occurrence
---@param range? Range
---@param count? integer
---@param register? string
---@param register_type? string
O.yank = Action.new(function(occurrence, range, count, register, register_type)
  local reg = Register.new(register, register_type)
  local edits = find_edits(occurrence, range, count)
  if edits then
    for edit in edits do
      local start_line, start_col, stop_line, stop_col = unpack(edit)
      Cursor:move(edit.stop)
      reg:add(vim.api.nvim_buf_get_text(0, start_line, start_col, stop_line, stop_col, {}))
    end
    reg:save()
  else
    log.debug("No marked occurrences found in motion")
  end
end)

-- Indent marked occurrences to the left.
-- @param occurrence Occurrence
-- @param range? Range
-- @param count? integer
O.indent_left = Action.new(function(occurrence, range, count)
  local edits = find_edits(occurrence, range, count)
  if edits then
    for edit in edits do
      Cursor:move(edit.stop)
      vim.cmd(string.format("%d,%d<", edit.start.line + 1, edit.stop.line + 1))
    end
  else
    log.debug("No marked occurrences found in motion")
  end
end)

-- Indent marked occurrences to the right.
-- @param occurrence Occurrence
-- @param range? Range
-- @param count? integer
O.indent_right = Action.new(function(occurrence, range, count)
  local edits = find_edits(occurrence, range, count)
  if edits then
    for edit in edits do
      Cursor:move(edit.stop)
      vim.cmd(string.format("%d,%d>", edit.start.line + 1, edit.stop.line + 1))
    end
  else
    log.debug("No marked occurrences found in motion")
  end
end)

-- change operator
O.c = O.change
-- delete operator
O.d = O.delete
-- yank operator
O.y = O.yank
-- indent left operator
O["<"] = O.indent_left
-- indent right operator
O[">"] = O.indent_right
-- toggle case operator
-- O["g~"] = O.toggle_case
-- lowercase operator
-- O["gu"] = O.to_lower
-- uppercase operator
-- O["gU"] = O.to_upper

-- - `"!"` - filter operator
-- - `"="` - format operator
-- - `"g?"` - ROT13 operator
-- - `"gq"` - format text operator
-- - `"gw"` - format text (keep cursor) operator

return O
