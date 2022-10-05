local Action = require("occurrency.Action")
local log = require("occurrency.log")

local NS = vim.api.nvim_create_namespace("Occurrency")

-- TODO: make hl groups
local OCCURRENCE_HL_GROUP = "Underlined" -- "Occurrence"

local M = {}

-- Clear all marks and highlights for the given occcurrence.
---@param occurrence Occurrence
function M.clear(occurrence)
  vim.api.nvim_buf_clear_namespace(occurrence.buffer, NS, 0, -1)
end

-- Add marks and highlights for all matches of the given occurrence.
---@param occurrence Occurrence
function M.all(occurrence)
  vim.api.nvim_buf_clear_namespace(occurrence.buffer, NS, 0, -1)
  if occurrence.has_match then
    local start_line = occurrence.line
    local start_col = occurrence.col
    repeat
      vim.api.nvim_buf_set_extmark(occurrence.buffer, NS, occurrence.line, occurrence.col, {})
      vim.api.nvim_buf_add_highlight(
        occurrence.buffer,
        NS,
        OCCURRENCE_HL_GROUP,
        occurrence.line,
        occurrence.col,
        occurrence.col + occurrence.span
      )
      occurrence:next()
    until occurrence.line == start_line and occurrence.col == start_col
  end
end

function M.add(occurrence) end

function M.del(occurrence) end

return Action:map(M)
