local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---Options for configuring operators.
---@class occurrence.OperatorKeymapOptions: { [string]: occurrence.OperatorConfig | occurrence.SupportedOperators | boolean | nil }
---@field ["c"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["d"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["y"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["<"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field [">"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["gu"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["gU"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["g~"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["g?"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["dd"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["cc"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["yy"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["C"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["D"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["Y"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["gq"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["gw"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["zf"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["="] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["!"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?
---@field ["g@"] occurrence.OperatorConfig | occurrence.SupportedOperators | boolean?

---Options for configuring keymaps.
---@class occurrence.KeymapOptions
---@field normal string?
---@field visual string?
---@field operator_pending string?
---@field operators occurrence.OperatorKeymapOptions?

---Options for configuring search.
---@class occurrence.SearchOptions
---@field enabled boolean?
---@field normal string?

---Options for configuring occurrence.
---@class occurrence.Options
---@field keymap occurrence.KeymapOptions?
---@field search occurrence.SearchOptions?

-- Default operator mappings :h operator
---@class occurrence.OperatorKeymapConfig: { [string]: occurrence.OperatorConfig | occurrence.SupportedOperators | boolean }
local DEFAULT_OPERATOR_KEYMAP_CONFIG = {
  ["c"] = "change",
  ["d"] = "delete",
  ["y"] = "yank",
  ["<"] = "indent_left",
  [">"] = "indent_right",

  ["gu"] = true, -- make lowercase
  ["gU"] = true, -- make uppercase
  ["g~"] = true, -- swap case
  ["g?"] = true, -- ROT13 encoding

  -- TODO: implement these
  ["dd"] = false, -- delete line
  ["cc"] = false, -- change line
  ["yy"] = false, -- yank line
  ["C"] = false, -- change to end of line
  ["D"] = false, -- delete to end of line
  ["Y"] = false, -- yank to end of line

  -- TODO: implement these
  ["gq"] = false, -- text formatting
  ["gw"] = false, -- text formatting with no cursor movement
  ["zf"] = false, -- define a fold
  ["="] = false, -- filter through 'equalprg' or C-indenting if empty
  ["!"] = false, -- filter through an external program
  ["g@"] = false, -- call function set with 'operatorfunc'
}

-- Default keymap configuration
---@class occurrence.KeymapConfig
local DEFAULT_KEYMAP_CONFIG = {
  ---@type string keymap to mark occurrences of the word under cursor to be targeted by the next operation. Default is 'go'.
  normal = "go",
  ---@type string keymap to mark occurrences of the visually selected subword to be targeted by the next operation. Default is 'go'.
  visual = "go",
  ---@type string keymap to modify a pending operation to target occurrences of the word under cursor. Default is 'o'.
  operator_pending = "o",
  ---@type occurrence.OperatorKeymapConfig configuration for operators.
  operators = DEFAULT_OPERATOR_KEYMAP_CONFIG,
}

-- Default search configuration
---@class occurrence.SearchConfig
local DEFAULT_SEARCH_CONFIG = {
  ---@type boolean enable search integration. Default is `true`.
  enabled = true,
  ---@type string? keymap to mark occurrences of the last search pattern to be targeted by the next operation.
  ---If this is `nil` or the same as `config.normal`, the word under cursor will be used if there is no active search.
  ---Default is `nil` (same as `config.normal`)
  normal = nil,
}

local DEFAULT_CONFIG = {
  keymap = DEFAULT_KEYMAP_CONFIG,
  search = DEFAULT_SEARCH_CONFIG,
}

---@class occurrence.Config
---@field keymap fun(self: occurrence.Config): occurrence.KeymapConfig
---@field search fun(self: occurrence.Config): occurrence.SearchConfig
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field get fun(self: occurrence.Config, key: string): occurrence.KeymapConfig|occurrence.SearchConfig|nil
local Config = {}

---@param opts? occurrence.Options
---@param key string
---@return occurrence.KeymapConfig|occurrence.SearchConfig|nil
---@overload fun(opts: occurrence.Options?, key: "keymap"): occurrence.KeymapConfig
---@overload fun(opts: occurrence.Options?, key: "search"): occurrence.SearchConfig
local function get(opts, key)
  if opts ~= nil and opts[key] ~= nil and DEFAULT_CONFIG[key] ~= nil then
    return vim.tbl_deep_extend("force", {}, DEFAULT_CONFIG[key], opts[key])
  else
    return vim.deepcopy(DEFAULT_CONFIG[key])
  end
end

---Validate the given options.
---Returns error message if the options represent an invalid configuration.
---@param opts occurrence.Options
---@return string? error_message
local function validate(opts)
  if type(opts) ~= "table" then
    return "opts must be a table"
  end
  for k, v in pairs(opts) do
    if DEFAULT_CONFIG[k] == nil then
      return "invalid option: " .. k
    end
    if type(v) ~= type(DEFAULT_CONFIG[k]) then
      return "option " .. k .. " must be a " .. type(DEFAULT_CONFIG[k])
    end
  end
  return nil
end

---Get a copy of the default configuration.
function config.default()
  return vim.deepcopy(DEFAULT_CONFIG)
end

---Check if the given options is already a config.
---@param opts any
---@return boolean
local function is_config(opts)
  return type(opts) == "table"
    and type(opts.keymap) == "function"
    and type(opts.search) == "function"
    and type(opts.validate) == "function"
    and type(opts.get) == "function"
end

---Validate and parse the given options.
---@param opts? occurrence.Options | occurrence.Config
---@return occurrence.Config
function config.new(opts)
  if is_config(opts) then
    ---@cast opts occurrence.Config
    return opts
  end
  ---@cast opts -occurrence.Config

  if opts ~= nil then
    local err = validate(opts)
    if err then
      log.warn_once(err)
      opts = nil
    end
  end

  return setmetatable({}, {
    __index = function(_, key)
      if key == "validate" then
        return function(_, o)
          return validate(o or opts)
        end
      end
      if key == "get" then
        return function(_, k)
          return get(opts, k)
        end
      end
      return function()
        return get(opts, key)
      end
    end,
    __newindex = function()
      error("cannot modify config")
    end,
  })
end

return config
