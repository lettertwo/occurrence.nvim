local Disposable = require("occurrence.Disposable")

local resolve_buffer = require("occurrence.resolve_buffer")

---@module 'occurrence.Keymap'
local keymap = {}

---@class occurrence.Keymap: occurrence.Disposable
---@field buffer integer The buffer the keymaps are in.
local Keymap = {}

---@param mode string | string[]
---@param lhs string
---@param rhs string | function
---@param opts? vim.keymap.set.Opts
function Keymap:set(mode, lhs, rhs, opts)
  assert(not self:is_disposed(), "Cannot use a disposed Keymap")
  opts = opts or {}
  opts.buffer = self.buffer
  self:add(function()
    pcall(vim.keymap.del, mode, lhs, opts)
  end)
  return vim.keymap.set(mode, lhs, rhs, opts)
end

---@param mode string | string[]
---@param lhs string
---@param opts? vim.keymap.del.Opts
function Keymap:del(mode, lhs, opts)
  assert(not self:is_disposed(), "Cannot use a disposed Keymap")
  opts = opts or {}
  opts.buffer = self.buffer
  return vim.keymap.del(mode, lhs, opts)
end

function Keymap:is_active()
  return not self:is_disposed() and #self._dispose_stack > 0
end

---@param buffer? integer
---@return occurrence.Keymap
function keymap.new(buffer)
  buffer = resolve_buffer(buffer, true)
  local disposable = Disposable.new()
  return setmetatable({}, {
    __index = function(tbl, key)
      if rawget(tbl, key) ~= nil then
        return rawget(tbl, key)
      elseif key == "buffer" then
        return buffer
      elseif Keymap[key] then
        return Keymap[key]
      elseif disposable[key] ~= nil then
        return disposable[key]
      end
    end,
  })
end

return keymap
