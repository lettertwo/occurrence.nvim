local M = {}

function M.reset()
  require("occurrency.Keymap"):reset()
end

---@param opts OccurrencyOptions
function M.setup(opts)
  local config = require("occurrency.Config"):new(opts)
  local Keymap = require("occurrency.Keymap")
  local actions = require("occurrency.actions")

  local activate_normal = actions.activate:bind(config)
  local activate_change = activate_normal:bind(actions.change_motion + actions.unmark_all + actions.deactivate)
  local activate_delete = activate_normal:bind(actions.delete_motion + actions.unmark_all + actions.deactivate)

  Keymap:n(
    config.normal,
    actions.find_cursor_word + actions.mark_all + activate_normal,
    "Occurrences of word under cursor"
  )
  Keymap:n(
    config.change,
    actions.find_cursor_word + actions.mark_all + activate_change,
    { expr = true, desc = "Occurrences of word under cursor" }
  )
  Keymap:n(
    config.delete,
    actions.find_cursor_word + actions.mark_all + activate_delete,
    { expr = true, desc = "Occurrences of word under cursor" }
  )
  Keymap:x(
    config.visual,
    actions.find_visual_subword + actions.mark_all + activate_normal,
    "Occurrences of visually selected subword"
  )
end

return M
