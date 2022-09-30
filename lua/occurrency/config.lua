local log = require("occurrency.log")

local M = {}

---@class OccurrencyConfig
local DEFAULT_CONFIG = {
  ---@type string keymap to modify a pending operation to target occurrences of word under cursor. Default is 'o'.
  word_modifier = "o",
  ---@type string keymap to modify a pending operation to target occurrences of subword under cursor. Default is 'O'.
  subword_modifier = "O",
  ---@type string keymap to mark occurrences of the word under cursor to be targeted by the next operation. Default is 'go'.
  word_operator = "go",
  ---@type string keymap to mark occurrences of the subword under cursor to be targeted by the next operation. Default is 'gO'.
  subword_operator = "gO",
}

---Options for configuring occurrency.
---@class OccurrencyOptions: OccurrencyConfig
---@field word_modifier? string
---@field subword_modifier? string
---@field word_operator? string
---@field subword_operator? string

---Validate the given options.
---@param opts OccurrencyOptions
---@return nil error if the options represent an invalid configuration.
function M.validate(opts)
  if type(opts) ~= "table" then
    error("opts must be a table")
  end
  for k, v in pairs(opts) do
    if DEFAULT_CONFIG[k] == nil then
      error("invalid option: " .. k)
    end
    if type(v) ~= type(DEFAULT_CONFIG[v]) then
      error("option " .. k .. " must be a " .. type(DEFAULT_CONFIG[v]))
    end
  end
end

---Validate and parse the given options.
---@param opts? OccurrencyOptions
---@return OccurrencyConfig config The configuration parsed from the given options, with defaults applied.
function M.parse(opts)
  if opts == nil then
    return DEFAULT_CONFIG
  end
  local ok, err = pcall(M.validate, opts)
  if not ok then
    log.warn_once(err)
    return DEFAULT_CONFIG
  end
  return vim.tbl_extend("force", DEFAULT_CONFIG, opts)
end

return M
