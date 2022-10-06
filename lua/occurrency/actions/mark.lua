local Action = require("occurrency.Action")
local log = require("occurrency.log")

local M = {}

-- Clear all marks and highlights for the given occcurrence.
---@param occurrence Occurrence
function M.clear(occurrence)
  if occurrence.has_match then
    local start_line = occurrence.line
    local start_col = occurrence.col
    repeat
      occurrence:unmark()
      occurrence:match()
    until occurrence.line == start_line and occurrence.col == start_col
  end
end

-- Add marks and highlights for all matches of the given occurrence.
---@param occurrence Occurrence
function M.all(occurrence)
  if occurrence.has_match then
    local start_line = occurrence.line
    local start_col = occurrence.col
    repeat
      occurrence:mark()
      occurrence:match()
    until occurrence.line == start_line and occurrence.col == start_col
  end
end

-- Add a mark and highlight for the current match of the given occurrence.
---@param occurrence Occurrence
function M.add(occurrence)
  if occurrence.has_match then
    occurrence:mark()
  end
end

-- Remove a mark and highlight for the current match of the given occurrence.
---@param occurrence Occurrence
function M.del(occurrence)
  if occurrence.has_match then
    occurrence:unmark()
  end
end

-- Go to the next mark.
---@param occurrence Occurrence
function M.next(occurrence)
  occurrence:match({ nearest = true, move = true, marked = true })
end

-- Go to the previous mark.
---@param occurrence Occurrence
function M.previous(occurrence)
  occurrence:match({ reverse = true, nearest = true, move = true, marked = true })
end

return Action:map(M)
