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
  Keymap:n(
    config.change,
    find.cursor_word + mark.all + buffer.activate("o", config) + operation.change,
    { expr = true, desc = "Occurrences of word under cursor" }
  )
  Keymap:n(
    config.delete,
    find.cursor_word + mark.all + buffer.activate("o", config) + operation.delete,
    { expr = true, desc = "Occurrences of word under cursor" }
  )
  Keymap:x(
    config.visual,
    find.visual_subword + mark.all + buffer.activate("x", config),
    "Occurrences of visually selected subword"
  )
end

return M
