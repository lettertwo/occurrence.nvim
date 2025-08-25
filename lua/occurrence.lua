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
  local Keymap = require("occurrence.Keymap")
  local actions = require("occurrence.actions")
  local config = require("occurrence.Config"):new(opts)

  Keymap:n(
    config.keymap.normal,
    actions.find_cursor_word + actions.mark_all + actions.activate:bind(config),
    { expr = true, desc = "Find occurrences of word under cursor" }
  )

  Keymap:x(
    config.keymap.visual,
    actions.find_visual_subword + actions.mark_all + actions.activate:bind(config),
    { expr = true, desc = "Find occurrences of selection" }
  )

  Keymap:o(
    config.keymap.operator_pending,
    actions.find_cursor_word + actions.mark_all + actions.activate_opfunc:bind(config),
    { expr = true, desc = "Operate on occurrences of word under cursor" }
  )

  if config.search.enabled then
    if config.search.normal == nil or config.search.normal == config.keymap.normal then
      -- If the search key is the same as the normal key, we will only use
      -- the search pattern if there is an active search, otherwise we
      -- will use the word under the cursor.
      Keymap:n(
        config.search.normal or config.keymap.normal,
        actions.find_active_search_or_cursor_word + actions.mark_all + actions.activate:bind(config),
        { expr = true, desc = "Find occurrences of active search or word under cursor" }
      )
    else
      Keymap:n(
        config.search.normal,
        actions.find_last_search + actions.mark_all + actions.activate:bind(config),
        { expr = true, desc = "Find occurrences of last search" }
      )
    end
  end
end

return M
