local Config = require("occurrence.Config")
local Modemap = require("occurrence.Modemap")

local log = require("occurrence.log")

local MODE = Modemap.MODE

-- A map of Buffer ids to their active keymaps.
---@type table<integer, occurrence.BufferKeymap>
local KEYMAP_CACHE = {}

---@param buffer? integer
---@param validate? boolean
local function resolve_buffer(buffer, validate)
  local resolved = buffer
  if resolved == nil or resolved == 0 then
    resolved = vim.api.nvim_get_current_buf()
  end
  if validate then
    assert(vim.api.nvim_buf_is_valid(resolved), "Invalid buffer: " .. tostring(buffer or resolved))
  end
  return resolved
end

---@module 'occurrence.Keymap'

-- A keymap utility that can be used to bind keys to actions.
-- It tracks active keymaps and can be used to neatly deactivate all of them.
---@class occurrence.Keymap
---@field active_keymaps occurrence.Modemap<{ [string]: true }> A table that tracks active keymaps.
---@field buffer? integer The buffer the keymap is bound to. If `nil`, the keymap is global.
---@field config? occurrence.Config The config this keymap was created with.
local Keymap = {
  active_keymaps = Modemap.new(),
}

---@class occurrence.BufferKeymap: occurrence.Keymap
---@field buffer integer The buffer this keymap is bound to.
---@field config? occurrence.Config The config this keymap was created with.

-- Creates a new keymap bound to a buffer.
-- If a keymap for the buffer already exists, it is reset and replaced.
---@param buffer? integer The buffer to bind to. Defaults to the current buffer.
---@param config? occurrence.Config
---@return occurrence.BufferKeymap
function Keymap.new(buffer, config)
  buffer = resolve_buffer(buffer, true)
  if KEYMAP_CACHE[buffer] ~= nil then
    KEYMAP_CACHE[buffer]:reset()
    KEYMAP_CACHE[buffer] = nil
  end
  ---@type occurrence.BufferKeymap
  local bound_keymap = {
    buffer = buffer,
    config = config,
    active_keymaps = Modemap.new(),
  }
  setmetatable(bound_keymap, { __index = Keymap })
  KEYMAP_CACHE[buffer] = bound_keymap
  return bound_keymap
end

-- Get the keymap for a buffer.
---@param buffer? integer The buffer to get the keymap for. Defaults to the current buffer.
---@return occurrence.BufferKeymap | nil
function Keymap.get(buffer)
  return KEYMAP_CACHE[resolve_buffer(buffer)]
end

-- Deletes the keymap for a buffer, if it exists.
-- This also resets all active keymaps registered by the instance.
---@param buffer? integer The buffer to delete the keymap for. Defaults to the current buffer.
---@return boolean
function Keymap.del(buffer)
  buffer = resolve_buffer(buffer)
  local keymap = KEYMAP_CACHE[buffer]
  if keymap then
    keymap:reset()
    KEYMAP_CACHE[buffer] = nil
    return true
  end
  return false
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
function Keymap:n(lhs, rhs, opts)
  local config = self.config or Config.new()
  vim.keymap.set(MODE.n, lhs, config:wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.n][lhs] = true
end

-- Register an operator-pending mode keymap.
---@param lhs string
---@param rhs occurrence.KeymapAction
---@param opts table | string
function Keymap:o(lhs, rhs, opts)
  local config = self.config or Config.new()
  vim.keymap.set(MODE.o, lhs, config:wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.o][lhs] = true
end

-- Register a visual mode keymap.
---@param lhs string
---@param rhs occurrence.KeymapAction
---@param opts table | string
function Keymap:v(lhs, rhs, opts)
  local config = self.config or Config.new()
  vim.keymap.set(MODE.v, lhs, config:wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.v][lhs] = true
end

-- Register multiple keymaps for a mode.
---@param mode occurrence.KeymapMode
---@param keymap_config occurrence.KeymapConfig
---@param config? occurrence.Config
function Keymap:map(mode, keymap_config, config)
  config = config or self.config or Config.new()
  for key, action in pairs(keymap_config) do
    local action_config = action ~= false and config:get_action_config(action, mode) or nil
    -- local resolved_action = action_config and config:get_action(action_config)
    if action_config then
      local desc = action_config.desc or ("'" .. key .. "' action")
      local expr = action_config.expr or false
      vim.keymap.set(mode, key, config:wrap_action(action_config), self:parse_opts({ desc = desc, expr = expr }))
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
  config = config or self.config or Config.new()
  local actions_config = config:actions()[mode]
  return self:map(mode, actions_config, config)
end

-- Map preset actions for a given mode.
---@param mode occurrence.KeymapMode
---@param config? occurrence.Config
function Keymap:map_preset_actions(mode, config)
  config = config or self.config or Config.new()
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

-- Autocmd to cleanup keymaps when a buffer is deleted.
vim.api.nvim_create_autocmd({ "BufDelete" }, {
  group = vim.api.nvim_create_augroup("OccurrenceKeymapCleanup", { clear = true }),
  callback = function(args)
    Keymap.del(args.buf)
  end,
})

return Keymap
