local M = {}

function M.reset()
  require("occurrency.Keymap"):reset()
end

---@param opts OccurrencyOptions
function M.setup(opts)
  local config = require("occurrency.config").parse(opts)
  local Keymap = require("occurrency.Keymap")
  local buffer = require("occurrency.actions.buffer")
  local mark = require("occurrency.actions.mark")
  local operation = require("occurrency.actions.operation")

  Keymap:n(config.normal_operator, mark.word + buffer.activate("n", config), "Occurrences of word under cursor")
  Keymap:x(
    config.visual_operator,
    mark.visual + buffer.activate("x", config),
    "Occurrences of visually selected subword"
  )
  Keymap:o(config.operator_modifier, mark.word + operation.run, "Occurrences of word under cursor")
end

return M
