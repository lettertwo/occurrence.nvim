local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.KeymapSetFn fun(mode: string|string[], lhs: string, rhs: string|function, opts?: vim.keymap.set.Opts)

---@class occurrence.Options
---@field default_keymaps? boolean
---@field default_operators? boolean
---@field on_preset_activate? fun(map: occurrence.KeymapSetFn): nil
---@field on_modify_operator? fun(operator: string): occurrence.OperatorConfig | nil

---@alias occurrence.PresetKeymapEntry occurrence.ActionConfig | occurrence.Api
---@class occurrence.PresetKeymapConfig: { [string]: occurrence.PresetKeymapEntry }
---@type occurrence.PresetKeymapConfig
local DEFAULT_PRESET_ACTIONS = {
  ["<Esc>"] = "deactivate",
  ["<C-c>"] = "deactivate",
  ["<C-[>"] = "deactivate",
  ["n"] = "goto_next",
  ["N"] = "goto_previous",
  ["gn"] = "goto_next_match",
  ["gN"] = "goto_previous_match",
  ["go"] = "toggle_mark",
  ["ga"] = "mark",
  ["gx"] = "unmark",
}

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | boolean
---@class occurrence.OperatorKeymapConfig: { [string]: occurrence.OperatorKeymapEntry }

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
  default_keymaps = true,
  default_operators = true,
  on_preset_activate = nil,
  on_modify_operator = nil,
}

-- Default operator configuration that is used
-- when an operator is enabled with `true`.
---@type occurrence.OperatorConfig
local DEFAULT_OPERATOR_CONFIG = {
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
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

---Validate the given options.
---Returns error message if the options represent an invalid configuration.
---@param opts occurrence.Options
---@return string? error_message
local function validate(opts)
  local ok, err = pcall(function()
    vim.validate("opts", opts, "table")

    local valid_keys = {
      default_keymaps = "boolean",
      default_operators = "boolean",
      on_preset_activate = "function",
      on_modify_operator = "function",
    }

    for key, validator in pairs(valid_keys) do
      vim.validate(key, opts[key], validator, true)
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

---@class occurrence.Config
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field default_keymaps boolean
---@field default_operators boolean
---@field on_preset_activate? fun(self: occurrence.Config, map: occurrence.KeymapSetFn): nil
---@field on_modify_operator? fun(self: occurrence.Config, operator: string): occurrence.OperatorConfig | nil
local Config = {}

---@param key string
---@return string
function Config:resolve_operator_key(key)
  local resolved = DEFAULT_OPERATOR_KEYMAP_CONFIG[key]
  local seen = {}
  while type(resolved) == "string" do
    if seen[key] then
      error("Circular operator alias detected: '" .. key .. "' <-> '" .. resolved .. "'")
    end
    seen[key] = true
    key = resolved
    resolved = DEFAULT_OPERATOR_KEYMAP_CONFIG[key]
  end
  return key
end

---@param name string
---@return occurrence.OperatorConfig | nil
function Config:get_operator_config(name)
  name = self:resolve_operator_key(name)
  local operator_config = DEFAULT_OPERATOR_KEYMAP_CONFIG[name]

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

---@param occurrence occurrence.Occurrence
function Config:activate_preset(occurrence)
  if self.default_keymaps then
    -- Disable the default operator-pending mapping.
    -- Note that this isn't strictly necessary, since the modify operator
    -- command is a no-op when there is a preset keymap active,
    -- but it gives some descriptive feedback to the user to update the binding.
    occurrence.keymap:set("o", "o", "<Nop>")

    -- Set up buffer-local keymaps for normal mode preset actions
    local api = require("occurrence.api")
    for key, action_name in pairs(DEFAULT_PRESET_ACTIONS) do
      local action_config = api[action_name]
      if action_config then
        local plug = action_config.plug or ("<Plug>Occurrence" .. to_capcase(action_name))
        local desc = action_config.desc
        local mode = action_config.mode or { "n", "v" }
        occurrence.keymap:set(mode, key, plug, { desc = desc })
      end
    end
  end

  if self.default_operators then
    -- Set up buffer-local keymaps for operators
    for operator_key in pairs(DEFAULT_OPERATOR_KEYMAP_CONFIG) do
      local operator_config = self:get_operator_config(operator_key)
      local operator = operator_config and require("occurrence.Operator").new(operator_key, operator_config)

      if operator then
        local desc = "'" .. operator_key .. "' on marked occurrences"
        if type(operator_config) == "table" and operator_config.desc then
          desc = operator_config.desc
        end

        -- Normal mode operator
        occurrence.keymap:set("n", operator_key, operator, { desc = desc, expr = true })

        -- Visual mode operator
        local visual_desc = "'" .. operator_key .. "' on marked occurrences in selection"
        if type(operator_config) == "table" and operator_config.desc then
          visual_desc = operator_config.desc .. " in selection"
        end

        occurrence.keymap:set("v", operator_key, operator, { desc = visual_desc, expr = true })
      end
    end
  end

  if callable(self.on_preset_activate) then
    self:on_preset_activate(function(mode, lhs, rhs, opts)
      occurrence.keymap:set(mode, lhs, rhs, opts)
    end)
  end
end

---@param occurrence occurrence.Occurrence
function Config:modify_operator(occurrence)
  local operator, count, register = vim.v.operator, vim.v.count, vim.v.register
  local operator_config = nil

  if callable(self.on_modify_operator) then
    operator_config = self:on_modify_operator(operator)
  end

  if not operator_config and self.default_operators then
    operator_config = self:get_operator_config(operator)
  end

  if not operator_config then
    log.warn(string.format("Operator '%s' is not supported", operator))
    occurrence:dispose()
    return
  end

  -- send <C-\><C\n> immediately to cancel pending op.
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)

  -- Schedule sending `g@` to trigger custom opfunc on the next frame.
  -- This is async to allow the first mode change event to cycle.
  -- If we did this synchronously, there would be no opportunity for
  -- other plugins (e.g. which-key) to react to the modified operator mode change.
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.schedule(function()
    if vim.v.operator ~= operator then
      log.debug("Operator changed from", operator, "to", vim.v.operator, "cancelling operator modifier")
      occurrence:dispose()
      return
    end

    log.debug("Activating operator-pending keymaps for buffer", occurrence.buffer)

    vim.api.nvim_create_autocmd("ModeChanged", {
      once = true,
      pattern = "*o*:*",
      callback = function()
        log.debug("Operator-pending mode exited, clearing occurrence for buffer", occurrence.buffer)
        occurrence:dispose()
      end,
    })

    require("occurrence.Operator").create_opfunc("o", occurrence, operator_config, operator, count, register)

    -- re-enter operator-pending mode
    vim.api.nvim_feedkeys("g@", "n", true)
    vim.cmd("redraw") -- ensure the screen is redrawn
  end)
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
      if key == "default_keymaps" or key == "default_operators" then
        if opts and opts[key] ~= nil then
          return opts[key]
        end
        return true -- default to true if not specified
      end
      if key == "on_preset_activate" or key == "on_modify_operator" then
        return opts and opts[key] or nil
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
