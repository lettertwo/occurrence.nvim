local M = {}

-- TODO: investigate undo breakpoints for iterative edits?
-- For example, this inserts an undo point whenver a comma is typed in insert mode:
-- vim.keymap.set("i", ",", ",<c-g>u")

-- TODO: look at https://github.com/ggandor/leap.nvim for implementation inspiration
-- perhaps there is a world where occurrence is a leap extension...

-- TODO: look at :h SafeState. Is this an event that can help with detecting pending ops?

-- TODO: look at :h command-preview. Can we get inc updating this way?

function M.reset()
  require("occurrence.Keymap"):reset()
end

---@param opts OccurrenceOptions
function M.setup(opts)
  local config = require("occurrence.Config"):new(opts)
  local Keymap = require("occurrence.Keymap")
  local actions = require("occurrence.actions")

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
