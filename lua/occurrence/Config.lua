local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.KeymapSetFn fun(mode: string|string[], lhs: string, rhs: string|function, opts?: vim.keymap.set.Opts)

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | string | false
---@alias occurrence.OperatorKeymapConfig { [string]: occurrence.OperatorKeymapEntry }

---@alias occurrence.KeymapEntry occurrence.Api | string
---@alias occurrence.KeymapConfig { [string]: occurrence.KeymapEntry }

---@class occurrence.Options
---@field default_keymaps? boolean
---@field default_operators? boolean
---@field keymaps? occurrence.KeymapConfig
---@field operators? occurrence.OperatorKeymapConfig
---@field on_activate? fun(map: occurrence.KeymapSetFn): nil
---@field get_operator_config? fun(operator: string): occurrence.OperatorConfig | nil

---@type { [string]: occurrence.Api }
local DEFAULT_OCCURRENCE_MODE_ACTIONS = {
  ["<Esc>"] = "deactivate",
  ["<C-c>"] = "deactivate",
  ["<C-[>"] = "deactivate",
  ["n"] = "next",
  ["N"] = "previous",
  ["gn"] = "match_next",
  ["gN"] = "match_previous",
  ["go"] = "toggle",
  ["ga"] = "mark",
  ["gx"] = "unmark",
}

---@type { [string]: occurrence.BuiltinOperator }
local DEFAULT_OPERATORS = {
  ["c"] = "change",
  ["d"] = "delete",
  ["y"] = "yank",
  ["p"] = "put",
  ["gp"] = "distribute",
  ["<"] = "indent_left",
  [">"] = "indent_right",
  ["="] = "indent_format",

  ["gu"] = "lowercase",
  ["gU"] = "uppercase",

  ["g~"] = "swap_case",
  ["g?"] = "rot13",
}

local DEFAULT_CONFIG = {
  keymaps = DEFAULT_OCCURRENCE_MODE_ACTIONS,
  operators = DEFAULT_OPERATORS,
  default_keymaps = true,
  default_operators = true,
  on_activate = nil,
}

---@param value occurrence.OperatorConfig
local function validate_operator_config(value)
  vim.validate("config", value, "table")
  vim.validate("method", value.method, function(val)
    return val == "visual_feedkeys" or val == "command" or val == "direct_api"
  end, '"visual_feedkeys", "command", or "direct_api"')
  vim.validate("uses_register", value.uses_register, "boolean")
  vim.validate("modifies_text", value.modifies_text, "boolean")
  if value.method == "direct_api" and value.modifies_text then
    vim.validate("replacement", value.replacement, { "string", "table", "callable", "nil" }, true)
  end
end

---@class occurrence.Config
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field default_keymaps boolean
---@field default_operators boolean
---@field keymaps occurrence.KeymapConfig
---@field operators occurrence.OperatorKeymapConfig
---@field on_activate? fun(map: occurrence.KeymapSetFn): nil
local Config = {}

---@param name string
---@return boolean
function Config:operator_is_supported(name)
  return not not self:get_operator_config(name)
end

---@param name occurrence.Api | string
---@return occurrence.ActionConfig | nil
function Config:get_api_config(name)
  local api_name = DEFAULT_OCCURRENCE_MODE_ACTIONS[name] or name
  local api = require("occurrence.api")
  return api[api_name]
end

---@param name string
---@return boolean
function Config:api_is_supported(name)
  return not not self:get_api_config(name)
end

---@param name string
---@return occurrence.OperatorConfig | nil
function Config:get_operator_config(name)
  local operator_config = nil
  operator_config = self.operators[name]
  -- Explicitly disabled operator
  if operator_config == false then
    return nil
  end

  if type(operator_config) == "string" then
    name = operator_config
    operator_config = nil
  end

  if operator_config == nil then
    local builtins = require("occurrence.operators")
    operator_config = builtins[name]
    ---@cast operator_config -occurrence.BuiltinOperator
  end

  if operator_config ~= nil then
    local ok, err = pcall(validate_operator_config, operator_config)
    if not ok then
      log.warn_once(string.format("Invalid operator config for '%s': %s", name, err))
      return nil
    end
  end

  return operator_config
end

---Check if the given options is already a config.
---@param opts any
---@return boolean
function config.is_config(opts)
  if type(opts) ~= "table" then
    return false
  end
  for key in pairs(Config) do
    if opts[key] == nil then
      return false
    end
  end
  return true
end

---Validate the given options.
---Returns error message if the options represent an invalid configuration.
---@param opts occurrence.Options
---@return string? error_message
function config.validate(opts)
  local ok, err = pcall(function()
    vim.validate("opts", opts, "table")

    ---@type { [string]: { [1]: string, [2]: boolean? } }
    local valid_keys = {
      operators = { "table", true },
      default_keymaps = { "boolean", true },
      default_operators = { "boolean", true },
      on_activate = { "callable", true },
    }

    for key, validator in pairs(valid_keys) do
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.validate(key, opts[key], unpack(validator))
    end

    if opts.operators then
      for op_key, op_value in pairs(opts.operators) do
        vim.validate("operator key", op_key, "string")
        vim.validate("operator value", op_value, { "table", "string", "boolean" })
        if type(op_value) == "table" then
          validate_operator_config(op_value)
        end
      end
    end

    for key in pairs(opts) do
      assert(valid_keys[key], string.format('unknown option "%s"', key))
    end
  end)

  if not ok then
    return tostring(err)
  end

  return nil
end

---Get a copy of the default configuration.
function config.default()
  return vim.deepcopy(DEFAULT_CONFIG)
end

---Validate and parse the given options.
---@param opts? occurrence.Options | occurrence.Config
---@return occurrence.Config
function config.new(opts, ...)
  -- if called like a method, e.g., `config:new()`,
  -- then `opts` will be the `config` module itself.
  if opts == config then
    return config.new(...)
  end

  if config.is_config(opts) then
    ---@cast opts occurrence.Config
    return opts
  end
  ---@cast opts -occurrence.Config

  if opts ~= nil then
    local err = config.validate(opts)
    if err then
      log.warn_once(err)
      opts = nil
    end
  end

  local self = vim.tbl_deep_extend("force", {}, DEFAULT_CONFIG, opts or {})

  if not self.default_operators then
    self.operators = (opts and opts.operators) or {}
  end

  return setmetatable({}, {
    __index = function(_, key)
      if self[key] ~= nil then
        return self[key]
      end
      if Config[key] ~= nil then
        return Config[key]
      end
    end,
    __newindex = function()
      error("cannot modify config")
    end,
  })
end

return config
