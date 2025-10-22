local feedkeys = require("occurrence.feedkeys")
local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.KeymapSetFn fun(mode: string|string[], lhs: string, rhs: string|function, opts?: vim.keymap.set.Opts)

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | string | false
---@alias occurrence.OperatorKeymapConfig { [string]: occurrence.OperatorKeymapEntry }

---@class occurrence.Options
---@field default_keymaps? boolean
---@field default_operators? boolean
---@field operators? occurrence.OperatorKeymapConfig
---@field on_preset_activate? fun(map: occurrence.KeymapSetFn): nil
---@field get_operator_config? fun(operator: string): occurrence.OperatorConfig | nil

---@type { [string]: occurrence.Api }
local DEFAULT_PRESET_ACTIONS = {
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
  operators = DEFAULT_OPERATORS,
  default_keymaps = true,
  default_operators = true,
  on_preset_activate = nil,
}

local function callable(fn)
  return type(fn) == "function" or (type(fn) == "table" and getmetatable(fn) and getmetatable(fn).__call)
end

-- Helper to convert snake_case to CapCase for <Plug> names
local function to_capcase(snake_str)
  local result = snake_str:gsub("_(%w)", function(c)
    return c:upper()
  end)
  return result:sub(1, 1):upper() .. result:sub(2)
end

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
---@field operators occurrence.OperatorKeymapConfig
---@field on_preset_activate? fun(map: occurrence.KeymapSetFn): nil
local Config = {}

---@param name string
---@return boolean
function Config:operator_is_supported(name)
  return not not self:get_operator_config(name)
end

---@param name occurrence.Api | string
---@return occurrence.ActionConfig | nil
function Config:get_api_config(name)
  local api_name = DEFAULT_PRESET_ACTIONS[name] or name
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

---@param occurrence occurrence.Occurrence
function Config:activate_preset(occurrence)
  if self.default_keymaps then
    -- Disable the default operator-pending mapping.
    -- Note that this isn't strictly necessary, since the modify operator
    -- command is a no-op when there is a preset keymap active,
    -- but it gives some descriptive feedback to the user to update the binding.
    occurrence.keymap:set("o", "o", "<Nop>")

    -- Set up buffer-local keymaps for normal mode preset actions
    for preset_key, action_name in pairs(DEFAULT_PRESET_ACTIONS) do
      local action_config = self:get_api_config(preset_key)
      if action_config then
        local plug = action_config.plug or ("<Plug>(Occurrence" .. to_capcase(action_name) .. ")")
        local desc = action_config.desc
        local mode = action_config.mode or { "n", "v" }
        occurrence.keymap:set(mode, preset_key, plug, { desc = desc })
      end
    end
  end

  -- Set up buffer-local keymaps for operators
  for operator_key in pairs(self.operators) do
    local operator_config = self:get_operator_config(operator_key)
    local operator = operator_config and require("occurrence.Operator").new(operator_key, operator_config)
    if operator_config and operator then
      local desc = operator_config.desc or ("'" .. operator_key .. "' on marked occurrences")
      occurrence.keymap:set({ "n", "v" }, operator_key, operator, { desc = desc, expr = true })
    else
      log.warn_once(string.format("Operator '%s' is not supported", operator_key))
    end
  end

  if callable(self.on_preset_activate) then
    self.on_preset_activate(function(mode, lhs, rhs, opts)
      occurrence.keymap:set(mode, lhs, rhs, opts)
    end)
  end
end

---@param occurrence occurrence.Occurrence
---@param operator_key? string If nil, modifies the pending operator.
function Config:modify_operator(occurrence, operator_key)
  local count, register = vim.v.count, vim.v.register
  operator_key = operator_key or vim.v.operator

  local operator_config = self:get_operator_config(operator_key)

  if not operator_config then
    log.warn(string.format("Operator '%s' is not supported", operator_key))
    -- If we have failed to modify the pending operator
    -- to use the occurrence, we should dispose of it.
    occurrence:dispose()
    return
  end

  -- cancel the pending op.
  feedkeys.change_mode("n", { force = true, noflush = true, silent = true })

  -- Schedule sending `g@` to trigger custom opfunc on the next frame.
  -- This is async to allow the first mode change event to cycle.
  -- If we did this synchronously, there would be no opportunity for
  -- other plugins (e.g. which-key) to react to the modified operator mode change.
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.schedule(function()
    log.debug("Activating operator-pending keymaps for buffer", occurrence.buffer)

    vim.api.nvim_create_autocmd("ModeChanged", {
      once = true,
      pattern = "*:n",
      callback = function()
        vim.schedule(function()
          log.debug("Operator-pending mode exited, clearing occurrence for buffer", occurrence.buffer)
          occurrence:dispose()
        end)
      end,
    })
    require("occurrence.Operator").create_opfunc("o", occurrence, operator_config, operator_key, count, register)
    -- re-enter operator-pending mode
    feedkeys.change_mode("o", { silent = true })
    vim.cmd("redraw") -- ensure the screen is redrawn
  end)
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
      on_preset_activate = { "callable", true },
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
