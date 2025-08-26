local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@class occurrence.KeymapConfig
local KeymapConfig = {
  ---@type string keymap to mark occurrences of the word under cursor to be targeted by the next operation. Default is 'go'.
  normal = "go",
  ---@type string keymap to mark occurrences of the visually selected subword to be targeted by the next operation. Default is 'go'.
  visual = "go",
  ---@type string keymap to modify a pending operation to target occurrences of the word under cursor. Default is 'o'.
  operator_pending = "o",
}

---@class occurrence.SearchConfig
local SearchConfig = {
  ---@type boolean enable search integration. Default is `true`.
  enabled = true,
  ---@type string? keymap to mark occurrences of the last search pattern to be targeted by the next operation.
  ---If this is `nil` or the same as `config.normal`, the word under cursor will be used if there is no active search.
  ---Default is `nil` (same as `config.normal`)
  normal = nil,
}

---@class occurrence.Config
local Config = {
  keymap = KeymapConfig,
  search = SearchConfig,
}

---Options for configuring occurrence.
---@class occurrence.Options: occurrence.Config
---@field operator_pending? string
---@field normal? string
---@field visual? string
---@field search? occurrence.SearchConfig

---Validate the given options.
---Errors if the options represent an invalid configuration.
---@param opts occurrence.Options
function Config:validate(opts)
  if type(opts) ~= "table" then
    error("opts must be a table")
  end
  for k, v in pairs(opts) do
    if self[k] == nil then
      error("invalid option: " .. k)
    end
    if type(v) ~= type(self[k]) then
      error("option " .. k .. " must be a " .. type(self[k]))
    end
  end
end

---Validate and parse the given options.
---@param opts? occurrence.Options
---@return occurrence.Config config The configuration parsed from the given options, with defaults applied.
function config.new(opts)
  local meta = {
    __index = Config,
    __newindex = function()
      error("cannot modify config")
    end,
  }
  if opts ~= nil then
    local ok, err = pcall(Config.validate, Config, opts)
    if ok then
      meta.__index = vim.tbl_extend("force", Config, opts)
    else
      log.warn_once(err)
    end
  end
  return setmetatable({}, meta)
end

return config
