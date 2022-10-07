local M = {}

function M.reset()
  require("occurrency.Keymap"):reset()
end

---@param opts OccurrencyOptions
function M.setup(opts)
  local config = require("occurrency.Config"):new(opts)
  local Keymap = require("occurrency.Keymap")
  local actions = require("occurrency.actions")

  Keymap:n(
    config.normal,
    actions.find_cursor_word + actions.mark_all + actions.activate_keymap:bind("n", config),
    "Occurrences of word under cursor"
  )
  Keymap:n(
    config.change,
    actions.find_cursor_word + actions.mark_all + actions.activate_keymap:bind("o", config) + actions.change,
    { expr = true, desc = "Occurrences of word under cursor" }
  )
  Keymap:n(
    config.delete,
    actions.find_cursor_word + actions.mark_all + actions.activate_keymap:bind("o", config) + actions.delete,
    { expr = true, desc = "Occurrences of word under cursor" }
  )
  Keymap:x(
    config.visual,
    actions.find_visual_subword + actions.mark_all + actions.activate_keymap:bind("x", config),
    "Occurrences of visually selected subword"
  )
end

return M
