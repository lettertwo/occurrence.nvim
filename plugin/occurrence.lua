---@module 'occurrence'
local occurrence = setmetatable({}, {
  __index = function(_, name)
    return function()
      require("occurrence")[name]()
    end
  end,
})

-- Register autocmd to setup occurrence automatically.
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  group = vim.api.nvim_create_augroup("OccurrenceAutoSetup", { clear = true }),
  once = true,
  callback = function()
    occurrence.setup()
  end,
})

return occurrence
