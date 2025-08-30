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

---Create a deep read-only table
---@param tbl table
---@return table
local function make_readonly(tbl)
  return setmetatable({}, {
    __index = function(_, key)
      local value = tbl[key]
      if type(value) == "table" then
        return make_readonly(value)
      end
      return value
    end,
    __newindex = function()
      error("cannot modify config")
    end,
    __pairs = function()
      return pairs(tbl)
    end,
    __ipairs = function()
      return ipairs(tbl)
    end,
  })
end

---Validate the given options.
---Returns error message if the options represent an invalid configuration.
---@param opts occurrence.Options
---@return string? error_message
function Config:validate(opts)
  if type(opts) ~= "table" then
    return "opts must be a table"
  end
  for k, v in pairs(opts) do
    if self[k] == nil then
      return "invalid option: " .. k
    end
    if type(v) ~= type(self[k]) then
      return "option " .. k .. " must be a " .. type(self[k])
    end
  end
  return nil
end

---Validate and parse the given options.
---@param opts? occurrence.Options
---@return occurrence.Config config The configuration parsed from the given options, with defaults applied.
function config.new(opts)
  local result_config = vim.deepcopy(Config)

  if opts ~= nil then
    local err = Config:validate(opts)
    if err then
      log.warn_once(err)
    else
      result_config = vim.tbl_deep_extend("force", result_config, opts)
    end
  end

  return make_readonly(result_config)
end

return config

