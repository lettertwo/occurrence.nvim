local Keymap = require("occurrency.Keymap")
local create_action = require("occurrency.action").create_action
local log = require("occurrency.log")
local mark = require("occurrency.actions.mark")

local M = {}

-- Creates an action to activate keybindings for the given configuration and mode.
---@param mode OccurrencyKeymapMode
---@param config OccurrencyConfig
---@return OccurrencyAction
function M.activate(mode, config)
  Keymap.validate_mode(mode)
  return create_action(
    -- Activate keybindings for the given buffer.
    -- If no buffer is given, the current buffer is used.
    ---@param buffer? integer
    function(buffer)
      buffer = buffer or vim.api.nvim_get_current_buf()
      log.debug("Activating keybindings for buffer", buffer, "and mode", mode)
      local keymap = Keymap:bind(buffer)
      -- TODO: mode-specific bindings

      -- Bind these regardless of the mode we're activating.
      -- TODO: Make this configurable.
      keymap:n("<Esc>", mark.clear + M.deactivate(keymap), "Clear marks and deactivate keybindings")
      log.debug("Activated buffer bindings")
    end
  )
end

-- Creates an action to deactivate the given keymap.
---@param keymap BufferKeymap
function M.deactivate(keymap)
  return create_action(function()
    keymap:reset()
    log.debug("Deactivated keybindings for buffer", keymap.buffer)
  end)
end

return M
