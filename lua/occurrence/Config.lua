local log = require("occurrence.log")

---@class OccurrenceConfig
local Config = {
  ---@type string keymap to mark occurrences of the word under cursor to be targeted by the next operation. Default is 'go'.
  normal = "go",
  ---@type string keymap to mark occurrences of the visually selected subword to be targeted by the next operation. Default is 'go'.
  visual = "go",
  ---@type string keymap to change occurrences of the word under cursor. Default is 'co'.
  change = "co",
  ---@type string keymap to delete occurrences of the word under cursor. Default is 'do'.
  delete = "do",
}

---Options for configuring occurrence.
---@class OccurrenceOptions: OccurrenceConfig
---@field operator_modifier? string
---@field normal_operator? string
---@field visual_operator? string

---Validate the given options.
---@param opts OccurrenceOptions
---@return nil error if the options represent an invalid configuration.
function Config:validate(opts)
  if type(opts) ~= "table" then
    error("opts must be a table")
  end
  for k, v in pairs(opts) do
    if self[k] == nil then
      error("invalid option: " .. k)
    end
    if type(v) ~= type(self[v]) then
      error("option " .. k .. " must be a " .. type(self[v]))
    end
  end
end

---Validate and parse the given options.
---@param opts? OccurrenceOptions
---@return OccurrenceConfig config The configuration parsed from the given options, with defaults applied.
function Config:new(opts)
  local meta = {
    __index = self,
    __newindex = function()
      error("cannot modify config")
    end,
  }
  if opts ~= nil then
    local ok, err = pcall(self.validate, self, opts)
    if ok then
      meta.__index = vim.tbl_extend("force", self, opts)
    else
      log.warn_once(err)
    end
  end
  return setmetatable({}, meta)
end

return Config
