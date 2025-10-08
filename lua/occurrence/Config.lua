local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.ActionConfig occurrence.PresetConfig | occurrence.OperatorModifierConfig

-- Function to be used as a callback for an action.
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
---@alias occurrence.ActionCallback fun(occurrence: occurrence.Occurrence, config: occurrence.Config): nil

---@alias occurrence.KeymapAction occurrence.PresetConfig | occurrence.OperatorModifierConfig | occurrence.Api | occurrence.ActionCallback | false

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | boolean
---@class occurrence.OperatorKeymapConfig: { [string]: occurrence.OperatorKeymapEntry }
---@class occurrence.OperatorKeymapOptions: { [string]?: occurrence.OperatorKeymapEntry }

---@alias occurrence.PresetMapFn fun(mode: string|string[], lhs: string, rhs: string|function, opts?: vim.keymap.set.Opts)

---@class occurrence.Options
---@field operators? occurrence.OperatorKeymapOptions
---@field default_keymaps? boolean
---@field on_preset_activate? fun(map: occurrence.PresetMapFn): nil

---@type occurrence.OperatorKeymapConfig
local DEFAULT_OPERATOR_KEYMAP_CONFIG = {
  -- operators
  ["c"] = "change",
  ["d"] = "delete",
  ["y"] = "yank",
  ["p"] = "put",
  ["<"] = "indent_left",
  [">"] = "indent_right",
  ["="] = "indent_format",

  ["gu"] = "lowercase",
  ["gU"] = "uppercase",

  ["g~"] = "swap_case",
  ["g?"] = "rot13",
}

local DEFAULT_CONFIG = {
  operators = DEFAULT_OPERATOR_KEYMAP_CONFIG,
  default_keymaps = true,
  on_preset_activate = nil,
}

-- Default operator configuration that is used
-- when an operator is enabled with `true`.
---@type occurrence.OperatorConfig
local DEFAULT_OPERATOR_CONFIG = {
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
}

---Validate the given options.
---Returns error message if the options represent an invalid configuration.
---@param opts occurrence.Options
---@return string? error_message
local function validate(opts)
  local ok, err = pcall(function()
    vim.validate("opts", opts, "table")

    local valid_keys = {
      operators = "table",
      default_keymaps = "boolean",
      on_preset_activate = "function",
    }

    for key, validator in pairs(valid_keys) do
      vim.validate(key, opts[key], validator, true)
    end

    if opts.operators then
      for key, value in pairs(opts.operators) do
        --- occurrence.OperatorConfig | occurrence.BuiltinOperator | boolean
        vim.validate(key, value, { "table", "boolean", "string" })
        if type(value) == "table" then
          vim.validate("method", value.method, "string")
          vim.validate("uses_register", value.uses_register, "boolean")
          vim.validate("modifies_text", value.modifies_text, "boolean")
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

---Check if the given options is already a config.
---@param opts any
---@return boolean
local function is_config(opts)
  return type(opts) == "table" and type(opts.validate) == "function"
end

local function callable(fn)
  return type(fn) == "function" or (type(fn) == "table" and getmetatable(fn) and getmetatable(fn).__call)
end

---@param key string
---@param operators_config occurrence.OperatorKeymapConfig
---@return string
local function resolve_operator_key(key, operators_config)
  local resolved = operators_config[key]
  local seen = {}
  while type(resolved) == "string" do
    if seen[key] then
      error("Circular operator alias detected: '" .. key .. "' <-> '" .. resolved .. "'")
    end
    seen[key] = true
    key = resolved
    resolved = operators_config[key]
  end
  return key
end

---@class occurrence.Config
---@field operators fun(self: occurrence.Config): occurrence.OperatorKeymapConfig
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field default_keymaps boolean
---@field on_preset_activate? fun(self: occurrence.Config, map: occurrence.PresetMapFn): nil
local Config = {}

---@param name string
---@return occurrence.OperatorConfig | nil
function Config:get_operator_config(name)
  local operators = self:operators()
  name = resolve_operator_key(name, operators)
  local operator_config = operators[name]

  if operator_config == nil then
    local builtins = require("occurrence.operators")
    operator_config = builtins[name]
  end

  if operator_config == true then
    operator_config = DEFAULT_OPERATOR_CONFIG
  end

  if type(operator_config) == "table" then
    return operator_config
  end
end

---@param name string
---@return boolean
function Config:operator_is_supported(name)
  return not not self:get_operator_config(name)
end

---@param name string
---@return occurrence.ActionConfig | nil
function Config:get_action_config(name)
  local builtins = require("occurrence.api")
  return builtins[name]
end

-- Wrap the given `action` in a function to be used as a keymap callback.
-- If `action` is a string, it will be resolved to a builtin action.
-- If `action` is a preset, operator, or operator-modifier config it will be created.
-- If `action` is a function, it will be treated as an action callback.
---@param action occurrence.KeymapAction
---@return function
function Config:wrap_action(action)
  ---@type { callback: occurrence.ActionCallback } | nil
  local action_config = nil

  if type(action) == "string" then
    action_config = self:get_action_config(action)
  elseif type(action) == "table" and action.type ~= nil then
    action_config = action
  elseif action and callable(action) then
    local Occurrence = require("occurrence.Occurrence")
    return function()
      return action(Occurrence.get(), self)
    end
  end

  if action_config and action_config.type then
    if action_config.type == "preset" then
      ---@cast action_config occurrence.PresetConfig
      return require("occurrence.Preset").new(action_config, self)
    elseif action_config.type == "operator-modifier" then
      ---@cast action_config occurrence.OperatorModifierConfig
      return require("occurrence.OperatorModifier").new(action_config, self)
    else
      error("Unsupported action type: " .. tostring(action_config.type))
    end
  end

  error("Invalid action " .. tostring(action))
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
      if key == "operators" then
        return function(_)
          local default_operators = DEFAULT_OPERATOR_KEYMAP_CONFIG
          if opts and opts.operators then
            return vim.tbl_deep_extend("force", vim.deepcopy(default_operators), opts.operators)
          end
          return default_operators
        end
      end
      if key == "default_keymaps" then
        if opts and opts.default_keymaps ~= nil then
          return opts.default_keymaps
        end
        return true -- default to true if not specified
      end
      if key == "on_preset_activate" then
        return opts and opts.on_preset_activate or nil
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
