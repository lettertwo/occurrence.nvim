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
      log.debug("Activating keybindings for buffer", occurrence.buffer, "and mode", mode)
      local keymap = Keymap:new(occurrence.buffer)
      -- TODO: mode-specific bindings

      -- Bind these regardless of the mode we're activating.
      -- TODO: Make this configurable.
      keymap:n("<Esc>", mark.clear + M.deactivate(keymap), "Clear marks and deactivate keybindings")
      log.debug("Activated buffer bindings")
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

return M
