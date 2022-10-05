local Keymap = require("occurrency.Keymap")
local Action = require("occurrency.Action")
local log = require("occurrency.log")
local mark = require("occurrency.actions.mark")

local M = {}

-- Creates an action to activate keybindings for the given configuration and mode.
---@param mode OccurrencyKeymapMode
---@param config OccurrencyConfig
---@return OccurrencyAction
function M.activate(mode, config)
  Keymap.validate_mode(mode)
  return Action:new(
    -- Activate keybindings for the given occurrence buffer.
    ---@param occurrence Occurrence
    function(occurrence)
      if not occurrence.has_match then
        log.debug("No match for occurrence; skipping activation")
        return
      end
      log.debug("Activating keybindings for buffer", occurrence.buffer, "and mode", mode)
      local keymap = Keymap:new(occurrence.buffer)
      -- TODO: mode-specific bindings
      keymap:n("n", M.next:bind(occurrence), "Next occurrence")
      keymap:n("N", M.previous:bind(occurrence), "Previous occurrence")
      keymap:n("a", mark.add:bind(occurrence), "Mark occurrence")
      keymap:n("x", mark.del:bind(occurrence), "Unmark occurrence")

      -- Bind these regardless of the mode we're activating.
      -- TODO: Make this configurable.
      keymap:n("<Esc>", mark.clear + M.deactivate(keymap):bind(occurrence), "Clear marks and deactivate keybindings")
    end
  )
end

-- Creates an action to deactivate the given keymap.
function M.deactivate(keymap)
  return Action:new(function()
    keymap:reset()
    log.debug("Deactivated keybindings for buffer", keymap.buffer)
  end)
end

-- Go to the next occurrence.
M.next = Action:new(function(occurrence)
  occurrence:next({ nearest = true, move = true })
end)

-- Go to the previous occurrence.
M.previous = Action:new(function(occurrence)
  occurrence:previous({ nearest = true, move = true })
end)

return M
