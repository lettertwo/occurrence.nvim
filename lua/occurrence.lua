---@module 'occurrence'
local occurrence = {}

local log = require("occurrence.log")

-- TODO: look at :h SafeState. Is this an event that can help with detecting pending ops?

-- TODO: look at :h command-preview. Can we get inc updating this way?

function occurrence.reset()
  require("occurrence.Keymap"):reset()
end

---@param opts occurrence.Options
function occurrence.setup(opts)
  local Keymap = require("occurrence.Keymap")
  local actions = require("occurrence.actions")
  local operators = require("occurrence.operators")
  local config = require("occurrence.Config").new(opts)
  local keymap_config = config:keymap()
  local search_config = config:search()

  Keymap:n(
    keymap_config.normal,
    actions.mark_cursor_word + actions.activate_preset:bind(config),
    { expr = true, desc = "Find occurrences of word" }
  )

  Keymap:x(
    keymap_config.visual,
    actions.mark_visual_subword + actions.activate_preset:bind(config),
    { expr = true, desc = "Find occurrences of selection" }
  )

  if vim.iter(keymap_config.operators):any(function(_, v)
    return v ~= false
  end) then
    vim.api.nvim_create_autocmd("ModeChanged", {
      pattern = "*:*o",
      callback = function()
        log.debug("ModeChanged to operator-pending")
        local operator = vim.v.operator
        if operators.is_supported(operator, config) then
          -- If a keymap exists, we assume that a preset occurrence is active.
          -- NOTE: Bindings for operators on preset occurrences
          -- are defined in `activate_preset` action.
          if not Keymap.get() then
            -- Bind the `activate_opfunc` action to the operator pending keymap.
            -- The assumption here is that, since there is no active keymap,
            -- there are no preset occurrences for the operator to use,
            -- so we want to activate occurrences of the cursor word and
            -- trigger the opfunc in one go.
            Keymap.new():o(
              keymap_config.operator_pending,
              actions.activate_opfunc:bind(config),
              { desc = "Occurrences of word", expr = true }
            )
          end
        end
      end,
    })
  end

  if search_config.enabled then
    if search_config.normal == nil or search_config.normal == keymap_config.normal then
      -- If the search key is the same as the normal key, we will only use
      -- the search pattern if there is an active search, otherwise we
      -- will use the word under the cursor.
      Keymap:n(
        search_config.normal or keymap_config.normal,
        actions.mark_active_search_or_cursor_word + actions.activate_preset:bind(config),
        { expr = true, desc = "Find occurrences of search or word" }
      )
    else
      Keymap:n(
        search_config.normal,
        actions.mark_last_search + actions.activate_preset:bind(config),
        { expr = true, desc = "Find occurrences of last search" }
      )
    end
  end
end

return occurrence
