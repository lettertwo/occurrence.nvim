local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.KeymapSetFn fun(mode: string|string[], lhs: string, rhs: string|function, opts?: vim.keymap.set.Opts)

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | string | false
---@alias occurrence.OperatorKeymapConfig { [string]: occurrence.OperatorKeymapEntry }

-- A configuration for an occurrence mode keymap.
-- A keymap defined this way will be buffer-local and
-- active only when occurrence mode is active.
---@class occurrence.KeymapConfig
-- The callback function to invoke when the keymap is triggered.
---@field callback occurrence.ActionCallback
-- The mode(s) in which the keymap is active.
-- Note that, regardless of these modes, the keymap will
-- only be active when occurrence mode is active.
---@field mode? "n" | "v" | ("n" | "v")[]
-- An optional description for the keymap.
-- Similar to the `desc` field in `:h vim.keymap.set` options.
---@field desc? string

---@alias occurrence.OccurrenceModeKeymapEntry occurrence.KeymapConfig | occurrence.Api | string | false
---@alias occurrence.OccurrenceModeKeymapConfig { [string]: occurrence.OccurrenceModeKeymapEntry }

-- Options for configuring occurrence.nvim.
-- Pass these to `require("occurrence").setup({ ... })`
-- to customize the plugin's behavior.
---@class occurrence.Options
-- Whether to include default keymaps.
--
-- If `false`, global keymaps, such as the default `go` to activate
-- occurrence mode, or the default `o` to modify a pending operator,
-- are not set, so activation keymaps must be set manually,
-- e.g., `vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceCurrent)")``
-- or `vim.keymap.set("o", "<C-o>", "<Plug>(OccurrenceModifyOperator)")`.
--
-- Additionally, when `false`, only keymaps explicitly defined in `keymaps`
-- will be automatically set when activating occurrence mode. Keymaps for
-- occurrence mode can also be set manually using the `on_activate` callback.
--
-- Default `operators` will still be set unless `default_operators` is also `false`.
--
-- Defaults to `true`.
---@field default_keymaps? boolean
-- Whether to include default operator support.
-- (c, d, y, p, gp, <, >, =, gu, gU, g~, g?)
--
-- If `false`, only operators explicitly defined in `operators`
-- will be supported.
--
-- Defaults to `true`.
---@field default_operators? boolean
-- A table defining keymaps that will be active in occurrence mode.
-- Each key is a string representing the keymap, and each value is either:
--   - a string representing the name of a built-in API action,
--   - a table defining a custom keymap configuration,
--   - or `false` to disable the keymap.
---@field keymaps? occurrence.OccurrenceModeKeymapConfig
-- A table defining operators that can be modified to operate on occurrences.
-- These operators will also be active as keymaps in occurrence mode.
-- Each key is a string representing the operator key, and each value is either:
--   - a string representing the name of a built-in operator,
--   - a table defining a custom operator configuration,
--   - or `false` to disable the operator.
---@field operators? occurrence.OperatorKeymapConfig
-- A callback that is invoked when occurrence mode is activated.
-- The callback receives a `map` function that can be used
-- to set additional keymaps for occurrence mode.
--
-- Any keymaps set using this `map` function will automatically be
-- buffer-local and will be removed when occurrence mode is deactivated.
--
-- Receives a function with the same signature as `:h vim.keymap.set`:
--`map(mode, lhs, rhs, opts)`
---@field on_activate? fun(map: occurrence.KeymapSetFn): nil

---@type { [string]: occurrence.Api }
local DEFAULT_OCCURRENCE_KEYMAPS = {
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
  keymaps = DEFAULT_OCCURRENCE_KEYMAPS,
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

---@param value occurrence.KeymapConfig
local function validate_keymap_config(value)
  vim.validate("config", value, "table")
  vim.validate("callback", value.callback, "callable")
  if value.mode then
    vim.validate("mode", value.mode, { "string", "table" }, true)
  end
  vim.validate("desc", value.desc, "string", true)
end

---@class occurrence.Config
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field default_keymaps boolean
---@field default_operators boolean
---@field keymaps occurrence.OccurrenceModeKeymapConfig
---@field operators occurrence.OperatorKeymapConfig
---@field on_activate? fun(map: occurrence.KeymapSetFn): nil
local Config = {}

---@param name string
---@return occurrence.ApiConfig | occurrence.KeymapConfig | nil
function Config:get_keymap_config(name)
  local keymap_config = nil
  keymap_config = self.keymaps[name]

  -- Explicitly disabled keymap
  if keymap_config == false then
    return nil
  end

  if type(keymap_config) == "string" then
    name = keymap_config
    keymap_config = nil
  end

  if keymap_config == nil then
    local api = require("occurrence.api")
    keymap_config = api[name]
    ---@cast keymap_config -occurrence.Api
  end

  -- Validate user-provided keymap config, but not built-in api configs
  if keymap_config ~= nil and self.keymaps[name] ~= nil and type(self.keymaps[name]) == "table" then
    local ok, err = pcall(validate_keymap_config, keymap_config)
    if not ok then
      log.warn_once(string.format("Invalid keymap config for '%s': %s", name, err))
      return nil
    end
  end

  return keymap_config
end

---@param name string
---@return boolean
function Config:keymap_is_supported(name)
  return not not self:get_keymap_config(name)
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

---@param name string
---@return boolean
function Config:operator_is_supported(name)
  return not not self:get_operator_config(name)
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
      keymaps = { "table", true },
      operators = { "table", true },
      default_keymaps = { "boolean", true },
      default_operators = { "boolean", true },
      on_activate = { "callable", true },
    }

    for key, validator in pairs(valid_keys) do
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.validate(key, opts[key], unpack(validator))
    end

    if opts.keymaps then
      for keymap_key, keymap_value in pairs(opts.keymaps) do
        vim.validate("keymap key", keymap_key, "string")
        vim.validate("keymap value", keymap_value, { "table", "string", "boolean" })
        if type(keymap_value) == "table" then
          validate_keymap_config(keymap_value)
        end
      end
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

  if not self.default_keymaps then
    self.keymaps = (opts and opts.keymaps) or {}
  end

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
