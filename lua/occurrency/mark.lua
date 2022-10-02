local create_actions = require("occurrency.action").create_actions
local log = require("occurrency.log")

local NS = vim.api.nvim_create_namespace("Occurrency")

local BUF_VAR = "occurrences"

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

local M = {}

local function get_cursor_word()
  return vim.fn.escape(vim.fn.expand("<cword>"), [[\/]]) ---@diagnostic disable-line: missing-parameter
end

-- local function get_cursor_pos()
--   local pos = vim.fn.getcurpos()
--   return pos[2], pos[3]
-- end

function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_del_var(bufnr, BUF_VAR)
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1) -- reset the ns, just in case.
end

function M.word(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- 1. find word under cursor.
  local cursorpos = vim.fn.getcurpos() -- store cursor position before searching.
  local word = get_cursor_word()
  local pattern = string.format([[\V\<%s\>]], word)
  local first_match = vim.fn.searchpos(pattern, "cw") -- 'c': accept match at cursor. 'w': wrap around EOF.
  local occurrences = { first_match }
  -- 2. find all other occurrences.
  local next_match = vim.fn.searchpos(pattern, "w")
  while (next_match[1] ~= first_match[1]) or (next_match[2] ~= first_match[2]) do
    table.insert(occurrences, next_match)
    next_match = vim.fn.searchpos(pattern, "w")
  end
  vim.fn.setpos(".", cursorpos) -- restore cursor position after search.

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1) -- reset the ns, just in case.
  vim.api.nvim_buf_set_var(bufnr, BUF_VAR, occurrences)

  -- 3. create marks and highlights for each occurrence. See `:h extmarks`.
  for _, occurrence in ipairs(occurrences) do
    local line = occurrence[1] - 1
    local col = occurrence[2] - 1
    -- TODO: determine if col and #word are byte counts or character counts.
    vim.api.nvim_buf_set_extmark(bufnr, NS, line, col, {})
    vim.api.nvim_buf_add_highlight(bufnr, NS, OCCURRENCE_HL_GROUP, line, col, col + #word)
  end
end

function M.visual(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- 1. find word under cursor.
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  local subword = table.concat(vim.api.nvim_buf_get_text(0, pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3], {}))

  print("mark.visual: " .. subword)
end

return create_actions(M)
