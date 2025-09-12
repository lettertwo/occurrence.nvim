local log = require("occurrence.log")
local Modemap = require("occurrence.Modemap")

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
  if KEYMAP_CACHE[buffer] ~= nil then
    KEYMAP_CACHE[buffer]:reset()
    KEYMAP_CACHE[buffer] = nil
  end
  ---@type occurrence.BufferKeymap
  local bound_keymap = {
    buffer = buffer,
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

--- Wraps an action in a function so that it can be used as a keymap callback.
---@param action string | function | occurrence.Action
---@return string | function
function Keymap.wrap_action(action)
  if type(action) == "table" then
    return function()
      return action()
    end
  end
  ---@cast action -occurrence.Action
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
---@param rhs string | function | occurrence.Action
---@param opts table | string
function Keymap:n(lhs, rhs, opts)
  vim.keymap.set(MODE.n, lhs, self.wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.n][lhs] = true
end

-- Register an operator-pending mode keymap.
---@param lhs string
---@param rhs string | function | occurrence.Action
---@param opts table | string
function Keymap:o(lhs, rhs, opts)
  vim.keymap.set(MODE.o, lhs, self.wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.o][lhs] = true
end

-- Register a visual mode keymap.
---@param lhs string
---@param rhs string | function | occurrence.Action
---@param opts table | string
function Keymap:v(lhs, rhs, opts)
  vim.keymap.set(MODE.v, lhs, self.wrap_action(rhs), self:parse_opts(opts))
  self.active_keymaps[MODE.v][lhs] = true
end

-- Resets all active keymaps registered by this instance.
function Keymap:reset()
  for mode, keymaps in pairs(self.active_keymaps) do
    for lhs in pairs(keymaps) do
      if not pcall(vim.keymap.del, mode, lhs, { buffer = self.buffer }) then
        log.warn_once("Failed to unmap " .. mode .. " " .. lhs)
      end
    end
    self.active_keymaps[mode] = nil
  end
end

-- Autocmd to cleanup keymaps when a buffer is deleted.
vim.api.nvim_create_autocmd({ "BufDelete" }, {
  -- group = vim.api.nvim_create_augroup("OccurrenceKeymapCleanup", { clear = true }),
  callback = function(args)
    Keymap.del(args.buf)
  end,
})

return Keymap
