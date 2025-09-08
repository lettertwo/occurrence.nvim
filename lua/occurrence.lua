---@module 'occurrence'
local occurrence = {}

-- TODO: look at :h SafeState. Is this an event that can help with detecting pending ops?

-- TODO: look at :h command-preview. Can we get inc updating this way?

function occurrence.reset()
  require("occurrence.Keymap"):reset()
end

---@param opts occurrence.Options
function occurrence.setup(opts)
  local Keymap = require("occurrence.Keymap")
  local actions = require("occurrence.actions")
  local config = require("occurrence.Config").new(opts)
  local keymap = config:keymap()
  local search = config:search()

  Keymap:n(
    keymap.normal,
    actions.mark_cursor_word + actions.activate:bind(config),
    { expr = true, desc = "Find occurrences of word under cursor" }
  )

  Keymap:x(
    keymap.visual,
    actions.mark_visual_subword + actions.activate:bind(config),
    { expr = true, desc = "Find occurrences of selection" }
  )

  Keymap:o(
    keymap.operator_pending,
    actions.mark_cursor_word + actions.activate_opfunc:bind(config),
    { expr = true, desc = "Operate on occurrences of word under cursor" }
  )

  if search.enabled then
    if search.normal == nil or search.normal == keymap.normal then
      -- If the search key is the same as the normal key, we will only use
      -- the search pattern if there is an active search, otherwise we
      -- will use the word under the cursor.
      Keymap:n(
        search.normal or keymap.normal,
        actions.mark_active_search_or_cursor_word + actions.activate:bind(config),
        { expr = true, desc = "Find occurrences of active search or word under cursor" }
      )
    else
      Keymap:n(
        search.normal,
        actions.mark_last_search + actions.activate:bind(config),
        { expr = true, desc = "Find occurrences of last search" }
      )
    end
  end
end

return occurrence
