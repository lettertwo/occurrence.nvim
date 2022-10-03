local M = {}

function M.reset()
  require("occurrency.keymap").reset()
end

---@param opts OccurrencyOptions
function M.setup(opts)
  local config = require("occurrency.config").parse(opts)
  local keymap = require("occurrency.keymap")
  local mark = require("occurrency.mark")
  local operation = require("occurrency.operation")

  keymap.n(config.normal_operator, mark.word + keymap.activate("n", config), "Occurrences of word under cursor")
  keymap.x(
    config.visual_operator,
    mark.visual + keymap.activate("x", config),
    "Occurrences of visually selected subword"
  )
  keymap.o(config.operator_modifier, mark.word + operation.run, "Occurrences of word under cursor")
end

return M
