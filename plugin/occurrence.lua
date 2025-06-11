---@module 'occurrence'
local occurrence = setmetatable({}, {
  __index = function(_, name)
    return function()
      require("occurrence")[name]()
    end
  end,
})

return occurrence
