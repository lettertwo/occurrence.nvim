local M = {}

local MODES = {}

setmetatable(MODES, {
  __index = function(_, key)
    local mode = rawget(MODES, key)
    if mode == nil then
      mode = {}
      rawset(MODES, key, mode)
    end
    return mode
  end,
})

--- Wraps an action in a function so that it can be used as a keymap callback.
---@param action string | function | OccurrencyAction
---@return string | function
function M.wrap_action(action)
  if type(action) == "table" then
    return function()
      return action()
    end
  end
  ---@cast action -OccurrencyAction
  return action
end

---Parse keymap options.
---@param opts table | string
---@return table #options with any defaults applied.
function M.parse_opts(opts)
  if type(opts) == "string" then
    return { desc = opts }
  end
  return opts
end

---Register a normal mode keymap.
---@param lhs string
---@param rhs string | function | OccurrencyAction
---@param opts table | string
function M.n(lhs, rhs, opts)
  vim.keymap.set("n", lhs, M.wrap_action(rhs), M.parse_opts(opts))
  table.insert(MODES.n, lhs)
end

---Register an operator-pending mode keymap.
---@param lhs string
---@param rhs string | function | OccurrencyAction
---@param opts table | string
function M.o(lhs, rhs, opts)
  vim.keymap.set("o", lhs, M.wrap_action(rhs), M.parse_opts(opts))
  table.insert(MODES.o, lhs)
end

---Register an visual or select mode keymap.
---@param lhs string
---@param rhs string | function | OccurrencyAction
---@param opts table | string
function M.x(lhs, rhs, opts)
  vim.keymap.set("x", lhs, M.wrap_action(rhs), M.parse_opts(opts))
  table.insert(MODES.x, lhs)
end

---Resets all keymaps registered by this module.
function M.reset()
  for _, mode in ipairs(MODES) do
    for _, lhs in ipairs(MODES[mode]) do
      vim.keymap.del(mode, lhs)
    end
    MODES[mode] = nil
  end
end

return M
