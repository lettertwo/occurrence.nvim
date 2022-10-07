local Action = require("occurrency.Action")
local log = require("occurrency.log")

local M = {}

local function opfunc(callback)
  -- FIXME: This is a hack around pending support for lua functions in this position.
  -- See https://github.com/neovim/neovim/pull/20187
  _G.OccurrencyOpfunc = function(...)
    callback(...)
    -- FIXME: This opfunc attempts to clean up after itself,
    -- but if the opeation is cancelled, the opfunc won't be called..
    _G.OccurrencyOpfunc = nil
  end
  vim.api.nvim_set_option("operatorfunc", "v:lua.OccurrencyOpfunc")
  return "g@"
end

M.change = Action:new(function(occurrence)
  return opfunc(function(type)
    log.debug("change", type, occurrence.pattern)
  end)
end)

M.delete = Action:new(function(occurrence, type)
  return opfunc(function(type)
    log.debug("delete", type, occurrence.pattern)
  end)
end)

return M
