local log = require("occurrence.log")

---@enum OccurrenceKeymapMode
local MODE = {
  n = "n", ---Normal mode.
  o = "o", ---Operator-pending mode.
  x = "x", ---Visual or select mode.
}

-- A table that maps modes to active keymaps.
---@class Modemap: table<OccurrenceKeymapMode, string[]>
local Modemap = {
  __index = function(self, key)
    assert(MODE[key], "Invalid mode: " .. key)
    local mode = rawget(self, key)
    if mode == nil then
      mode = {}
      rawset(self, key, mode)
    end
    return mode
  end,
}

---@return Modemap
function Modemap:new()
  return setmetatable({}, self)
end

-- A keymap utility that can be used to bind keys to actions.
-- It tracks active bindings and can be used to neatly deactivate all of them.
---@class Keymap
---@field active_keymaps Modemap A table that maps modes to active keymaps.
---@field buffer? integer The buffer the keymap is bound to. If `nil`, the keymap is global.
local Keymap = {
  active_keymaps = Modemap:new(),
}

---@class BufferKeymap: Keymap
---@field buffer integer The buffer this keymap is bound to.

-- Creates a new keymap bound to a buffer.
---@param buffer integer The buffer to bind to.
---@return BufferKeymap
function Keymap:new(buffer)
  ---@type BufferKeymap
  local bound_keymap = {
    buffer = buffer,
    active_keymaps = Modemap:new(),
  }
  setmetatable(bound_keymap, { __index = self })
  return bound_keymap
end

---@param mode OccurrenceKeymapMode
---@return nil error if the mode is invalid.
function Keymap.validate_mode(mode)
  assert(MODE[mode], "Invalid mode: " .. mode)
end

--- Wraps an action in a function so that it can be used as a keymap callback.
---@param action string | function | Action
---@return string | function
function Keymap.wrap_action(action)
  if type(action) == "table" then
    return function()
      return action()
    end
  end
  ---@cast action -Action
  return action
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
---@param rhs string | function | Action
---@param opts table | string
function Keymap:n(lhs, rhs, opts)
  vim.keymap.set(MODE.n, lhs, self.wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.n][lhs] = true
end

-- Register an operator-pending mode keymap.
---@param lhs string
---@param rhs string | function | Action
---@param opts table | string
function Keymap:o(lhs, rhs, opts)
  vim.keymap.set(MODE.o, lhs, self.wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.o][lhs] = true
end

-- Register a visual or select mode keymap.
---@param lhs string
---@param rhs string | function | Action
---@param opts table | string
function Keymap:x(lhs, rhs, opts)
  vim.keymap.set(MODE.x, lhs, self.wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.x][lhs] = true
end

-- Resets all active keymaps registered by this instance.
function Keymap:reset()
  for mode, bindings in pairs(self.active_keymaps) do
    for lhs in pairs(bindings) do
      if not pcall(vim.keymap.del, mode, lhs, { buffer = self.buffer }) then
        log.warn("Failed to unmap " .. mode .. " " .. lhs)
      end
    end
    self.active_keymaps[mode] = nil
  end
end

return Keymap
