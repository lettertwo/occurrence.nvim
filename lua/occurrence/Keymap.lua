local Config = require("occurrence.Config")
local Modemap = require("occurrence.Modemap")

local log = require("occurrence.log")
local resolve_buffer = require("occurrence.resolve_buffer")

local MODE = Modemap.MODE

---@module 'occurrence.Keymap'

-- A keymap utility that can be used to bind keys to actions.
-- It tracks active keymaps and can be used to neatly deactivate all of them.
---@class occurrence.Keymap
---@field active_keymaps occurrence.Modemap<{ [string]: true }> A table that tracks active keymaps.
---@field buffer? integer The buffer the keymap is bound to. If `nil`, the keymap is global.
local Keymap = {
  active_keymaps = Modemap.new(),
}

---@class occurrence.BufferKeymap: occurrence.Keymap
---@field buffer integer The buffer this keymap is bound to.

-- Creates a new keymap bound to a buffer.
-- If a keymap for the buffer already exists, it is reset and replaced.
---@param buffer? integer The buffer to bind to. Defaults to the current buffer.
---@return occurrence.BufferKeymap
function Keymap.new(buffer)
  buffer = resolve_buffer(buffer, true)

  ---@type occurrence.BufferKeymap
  local bound_keymap = {
    buffer = buffer,
    active_keymaps = Modemap.new(),
  }
  setmetatable(bound_keymap, { __index = Keymap })
  return bound_keymap
end

---@param mode occurrence.KeymapMode
---@return nil error if the mode is invalid.
function Keymap.validate_mode(mode)
  assert(MODE[mode], "Invalid mode: " .. mode)
end

-- Parse keymap options.
---@param opts table | string
---@return table #options with any defaults applied.
function Keymap:parse_opts(opts)
  if type(opts) == "string" then
    opts = { desc = opts }
  end
  return vim.tbl_extend("error", { buffer = self.buffer }, opts)
end

-- Register a normal mode keymap.
---@param lhs string
---@param rhs occurrence.KeymapAction
---@param opts table | string
---@param config? occurrence.Config
function Keymap:n(lhs, rhs, opts, config)
  config = config or Config.new()
  vim.keymap.set(MODE.n, lhs, config:wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.n][lhs] = true
end

-- Register an operator-pending mode keymap.
---@param lhs string
---@param rhs occurrence.KeymapAction
---@param opts table | string
---@param config? occurrence.Config
function Keymap:o(lhs, rhs, opts, config)
  config = config or Config.new()
  vim.keymap.set(MODE.o, lhs, config:wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.o][lhs] = true
end

-- Register a visual mode keymap.
---@param lhs string
---@param rhs occurrence.KeymapAction
---@param opts table | string
---@param config? occurrence.Config
function Keymap:v(lhs, rhs, opts, config)
  config = config or Config.new()
  vim.keymap.set(MODE.v, lhs, config:wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.v][lhs] = true
end

-- Register multiple keymaps for a mode.
---@param mode occurrence.KeymapMode
---@param keymap_config occurrence.KeymapConfig
---@param config? occurrence.Config
function Keymap:map(mode, keymap_config, config)
  config = config or Config.new()
  for key, action in pairs(keymap_config) do
    local action_config = action ~= false and config:get_action_config(action, mode) or nil
    if action_config then
      local desc = action_config.desc or ("'" .. key .. "' action")
      vim.keymap.set(mode, key, config:wrap_action(action_config), self:parse_opts({ desc = desc }))
      self.active_keymaps[mode][key] = true
    elseif action ~= false then
      if type(action) == "string" then
        log.warn_once("No action '" .. action .. "' found for keymap '" .. key .. "' in mode " .. mode)
      else
        log.warn_once("Invalid action for keymap '" .. key .. "' in mode " .. mode)
      end
    end
  end
end

-- Map actions for a given mode.
---@param mode occurrence.KeymapMode
---@param config? occurrence.Config
function Keymap:map_actions(mode, config)
  config = config or Config.new()
  local actions_config = config:actions()[mode]
  return self:map(mode, actions_config, config)
end

-- Map preset actions for a given mode.
---@param mode occurrence.KeymapMode
---@param config? occurrence.Config
function Keymap:map_preset_actions(mode, config)
  config = config or Config.new()
  local preset_actions = config:preset_actions()[mode]
  return self:map(mode, preset_actions, config)
end

-- Resets all active keymaps registered by this instance.
function Keymap:reset()
  for mode, keymaps in pairs(self.active_keymaps) do
    for lhs in pairs(keymaps) do
      if not pcall(vim.keymap.del, mode, lhs, { buffer = self.buffer }) then
        log.warn_once("Failed to unmap " .. mode .. " " .. lhs)
      end
    end
  end
  self.active_keymaps = Modemap.new()
end

return Keymap
