local M = {}

function M.reset()
  require("occurrency.Keymap"):reset()
end

---@param opts OccurrencyOptions
function M.setup(opts)
  local config = require("occurrency.Config"):new(opts)
  local Keymap = require("occurrency.Keymap")
  local buffer = require("occurrency.actions.buffer")
  local mark = require("occurrency.actions.mark")
  local operation = require("occurrency.actions.operation")
  local find = require("occurrency.actions.find")

  Keymap:n(
    config.normal,
    find.cursor_word + mark.all + buffer.activate("n", config),
    "Occurrences of word under cursor"
  )
  Keymap:x(
    config.visual,
    find.visual_subword + mark.all + buffer.activate("x", config),
    "Occurrences of visually selected subword"
  )
end

return M
