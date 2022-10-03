local create_actions = require("occurrency.action").create_actions
local log = require("occurrency.log")

local NS = vim.api.nvim_create_namespace("Occurrency")

local BUF_VAR = "occurrences"

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

-- Get the word under the cursor in the given buffer.
---@param bufnr integer
local function get_cursor_word(bufnr)
  assert(bufnr == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  return vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
end

-- Extract visually selected text in the given buffer.
---@param bufnr integer
local function get_visual_text(bufnr)
  assert(bufnr == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  return table.concat(vim.api.nvim_buf_get_text(0, pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3], {}))
end

-- Find all occurrences of `text` in the given buffer.
---@param bufnr integer
---@param pattern string
---@return integer[][]
local function find_occurrences(bufnr, pattern)
  assert(bufnr == vim.api.nvim_get_current_buf(), "bufnr not matching the current buffer not yet supported")
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.
  local first_match = vim.fn.searchpos(pattern, "cw") -- 'c': accept match at cursor. 'w': wrap around EOF.
  local occurrences = { first_match }
  local next_match = vim.fn.searchpos(pattern, "w")
  while (next_match[1] ~= first_match[1]) or (next_match[2] ~= first_match[2]) do
    table.insert(occurrences, next_match)
    next_match = vim.fn.searchpos(pattern, "w")
  end
  vim.fn.setpos(".", cursorpos) -- restore cursor position after search.
  return occurrences
end

-- Create marks and highlights for each occurrence of `text`.
-- See `:h extmarks`.
---@param bufnr integer
---@param text string
---@param opts? {is_word: boolean}
local function mark_occurrences(bufnr, text, opts)
  local occurrences = {}
  local pattern = opts and opts.is_word and string.format([[\V\<%s\>]], text) or string.format([[\V%s]], text)
  for _, occurrence in ipairs(find_occurrences(bufnr, pattern)) do
    local line = occurrence[1] - 1
    local col = occurrence[2] - 1
    table.insert(occurrences, vim.api.nvim_buf_set_extmark(bufnr, NS, line, col, {}))
    vim.api.nvim_buf_add_highlight(bufnr, NS, OCCURRENCE_HL_GROUP, line, col, col + #text)
  end
  vim.api.nvim_buf_set_var(bufnr, BUF_VAR, occurrences)
end

local M = {}

-- Clear all marks and highlights in the given buffer.
-- If no buffer is given, clear marks and highlights in the current buffer.
---@param bufnr? integer
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  vim.api.nvim_buf_del_var(bufnr, BUF_VAR)
end

-- Mark all occurrences of the word under the cursor in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
---@param bufnr? integer
function M.word(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  mark_occurrences(bufnr, get_cursor_word(bufnr), { is_word = true })
end

-- Mark all occurrences of the visually selected text in the given buffer.
-- If no buffer is given, mark occurrences in the current buffer.
---@param bufnr? integer
function M.visual(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  mark_occurrences(bufnr, get_visual_text(bufnr))
end

return create_actions(M)
