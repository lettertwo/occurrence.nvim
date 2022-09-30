local create_actions = require("occurrency.action").create_actions

local M = {}

function M.word()
  local word = vim.fn.expand("<cword>") ---@diagnostic disable-line: missing-parameter
  print("mark.word: " .. word)
end

function M.visual()
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(".")
  local subword = table.concat(vim.api.nvim_buf_get_text(0, pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3], {}))

  print("mark.visual: " .. subword)
end

return create_actions(M)
