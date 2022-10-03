local M = {}

local prev_opts = {}

function M.setup(opts)
  if opts == nil then
    opts = prev_opts
  end
  local log = require("occurrency.log")
  log.set_level(log.levels.DEBUG)
  prev_opts = opts
  log.debug("occurrency.dev.setup(" .. vim.inspect(opts) .. ")")
  require("occurrency").setup(opts)
end

function M.reload()
  require("occurrency").reset() -- Reset twice; once before reload, and...
  ---@diagnostic disable-next-line: undefined-field
  local luacache = (_G.__luacache or {}).cache -- impatient.nvim cache
  local module_name_pattern = vim.pesc("occurrency")
  local log = require("occurrency.log")
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
  require("occurrency").reset() -- ...once after reload.
  M.setup()
end

vim.api.nvim_create_user_command("ReloadOccurrency", M.reload, {
  desc = "Reload the occurrency plugin and run setup again",
  force = true,
})

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = { "*/occurrency.nvim/lua/*.lua" },
  command = "ReloadOccurrency",
  group = vim.api.nvim_create_augroup("OccurrencyDev", { clear = true }),
})

return M
