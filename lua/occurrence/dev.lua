---@module 'occurrence.dev'
local dev = {}

local prev_opts = {}

function dev.setup(opts)
  if opts == nil then
    opts = prev_opts
  end
  local log = require("occurrence.log")
  log.set_level(log.levels.DEBUG)
  prev_opts = opts

  require("occurrence.command").add("reload", {
    impl = function()
      dev.reload()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = { "*/occurrence.nvim*/lua/*.lua" },
    command = "Occurrence reload",
    group = vim.api.nvim_create_augroup("OccurrenceDev", { clear = true }),
  })

  log.debug("occurrence.dev.setup(" .. vim.inspect(opts) .. ")")
  require("occurrence").setup(opts)
end

function dev.reload()
  require("occurrence").reset() -- Reset twice; once before reload, and...
  ---@diagnostic disable-next-line: undefined-field
  local luacache = (_G.__luacache or {}).cache -- impatient.nvim cache
  local module_name_pattern = vim.pesc("occurrence")
  local log = require("occurrence.log")
  for pack, _ in pairs(package.loaded) do
    if string.find(pack, "^" .. module_name_pattern) then
      log.set_level(log.levels.DEBUG)
      log.debug("unloading " .. pack)
      package.loaded[pack] = nil
      if luacache then
        luacache[pack] = nil
      end
    end
  end
  require("occurrence").reset() -- ...once after reload.
  dev.setup()
end

return dev
