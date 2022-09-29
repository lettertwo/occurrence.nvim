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

function M.parse_opts(opts)
  if type(opts) == "string" then
    return { desc = opts }
  end
  return opts
end

function M.n(lhs, rhs, opts)
  vim.keymap.set("n", lhs, rhs, M.parse_opts(opts))
  table.insert(MODES.n, lhs)
end

function M.o(lhs, rhs, opts)
  vim.keymap.set("o", lhs, rhs, M.parse_opts(opts))
  table.insert(MODES.o, lhs)
end

function M.x(lhs, rhs, opts)
  vim.keymap.set("x", lhs, rhs, M.parse_opts(opts))
  table.insert(MODES.x, lhs)
end

function M.reset()
  for _, mode in ipairs(MODES) do
    for _, lhs in ipairs(MODES[mode]) do
      vim.keymap.del(mode, lhs)
    end
    MODES[mode] = nil
  end
end

return M
