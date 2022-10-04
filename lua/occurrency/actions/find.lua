local Action = require("occurrency.Action")
local log = require("occurrency.log")

-- Get the word under the cursor in the given buffer.
---@param buffer integer
local function get_cursor_word(buffer)
  assert(buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  return vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
end

-- Extract visually selected text in the given buffer.
---@param buffer integer
local function get_visual_text(buffer)
  assert(buffer == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  return table.concat(vim.api.nvim_buf_get_text(0, pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3], {}))
end

local M = {}

-- Find all occurrences of the word under the cursor in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
---@param occurrence Occurrence
function M.cursor_word(occurrence)
  occurrence:set(get_cursor_word(occurrence.buffer), { is_word = true })
end

-- Mark all occurrences of the visually selected text in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
---@param occurrence Occurrence
function M.visual_subword(occurrence)
  occurrence:set(get_visual_text(occurrence.buffer))
end

return Action:map(M)
