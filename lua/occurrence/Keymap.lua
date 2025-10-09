local Disposable = require("occurrence.Disposable")

local resolve_buffer = require("occurrence.resolve_buffer")

---@module 'occurrence.Keymap'
local keymap = {}

---@class occurrence.Keymap: occurrence.Disposable
---@field buffer integer The buffer the keymaps are in.
local Keymap = {}

---Save the current keymap for the given mode and lhs
---@param buffer integer
---@param mode string | string[]
---@param lhs string
---@return vim.api.keyset.get_keymap[]?
local function save_keymaps(buffer, mode, lhs)
  local saved_maps = {}
  if type(mode) ~= "table" then
    mode = { mode }
  end
  for _, m in ipairs(mode) do
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buffer, m)) do
      if map.lhs == lhs then
        table.insert(saved_maps, map)
      end
    end
  end
  return #saved_maps > 0 and saved_maps or nil
end

---Restore previously saved keymaps
---@param buffer integer
---@param maps vim.api.keyset.get_keymap[]
local function restore_keymaps(buffer, maps)
  for _, map in ipairs(maps) do
    local rhs = map.callback or map.rhs
    if map.buffer == buffer and rhs then
      vim.keymap.set(map.mode, map.lhs, rhs, {
        buffer = buffer,
        expr = map.expr == 1,
        noremap = map.noremap == 1,
        nowait = map.nowait == 1,
        silent = map.silent == 1,
        script = map.script == 1,
      })
    end
  end
end

---@param mode string | string[]
---@param lhs string
---@param rhs string | function
---@param opts? vim.keymap.set.Opts
function Keymap:set(mode, lhs, rhs, opts)
  assert(not self:is_disposed(), "Cannot use a disposed Keymap")
  opts = opts or {}
  opts.buffer = self.buffer

  -- Save existing keymaps so we can restore them later.
  local saved = save_keymaps(self.buffer, mode, lhs)

  self:add(function()
    -- Delete the keymap we created
    pcall(vim.keymap.del, mode, lhs, opts)

    -- Restore previous keymap if it existed
    if saved then
      restore_keymaps(self.buffer, saved)
    end
  end)

  return vim.keymap.set(mode, lhs, rhs, opts)
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
