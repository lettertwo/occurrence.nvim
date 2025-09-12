---@module 'occurrence.Modemap'
local modemap = {}

---@enum occurrence.KeymapMode
local MODE = {
  n = "n", ---Normal mode.
  o = "o", ---Operator-pending mode.
  v = "v", ---Visual mode.
}

modemap.MODE = MODE

local Modemap_mt = {
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

-- A table that maps modes to active keymaps.
---@class occurrence.Modemap<T>: { [occurrence.KeymapMode]: T }

---@return occurrence.Modemap
function modemap.new()
  return setmetatable({}, Modemap_mt)
end

return modemap
