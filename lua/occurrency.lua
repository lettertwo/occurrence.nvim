local M = {}

function M.reset()
  require("occurrency.keymap").reset()
end

---@param opts OccurrencyOptions
function M.setup(opts)
  local config = require("occurrency.config").parse(opts)
  local keymap = require("occurrency.keymap")
  -- keymap.n("cg*", '*N"_cgn', "Find next occurrence of word under cursor")
end

return M
