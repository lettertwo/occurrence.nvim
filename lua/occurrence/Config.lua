local log = require("occurrence.log")

---@alias occurrence.ActionConfig occurrence.PresetConfig | occurrence.OperatorModifierConfig

-- Function to be used as a callback for an action.
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
---@alias occurrence.ActionCallback fun(occurrence: occurrence.Occurrence, config: occurrence.Config): nil

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.KeymapAction occurrence.PresetConfig | occurrence.OperatorModifierConfig | occurrence.BuiltinAction | occurrence.ActionCallback | false

---@class occurrence.KeymapConfig
---@field n { [string]: occurrence.KeymapAction } normal mode keymaps
---@field v { [string]: occurrence.KeymapAction } visual mode keymaps
---@field o { [string]: occurrence.KeymapAction } operator-pending mode keymaps

---@class occurrence.KeymapOptions
---@field n? { [string]?: occurrence.KeymapAction } normal mode keymaps
---@field v? { [string]?: occurrence.KeymapAction } visual mode keymaps
---@field o? { [string]?: occurrence.KeymapAction } operator-pending mode keymaps

---@class occurrence.ActivePresetKeymapConfig
---@field n { [string]: occurrence.KeymapAction } normal mode keymaps
---@field v { [string]: occurrence.KeymapAction } visual mode keymaps

---@class occurrence.ActivePresetKeymapOptions
---@field n? { [string]?: occurrence.KeymapAction } normal mode keymaps
---@field v? { [string]?: occurrence.KeymapAction } visual mode keymaps

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | boolean
---@class occurrence.OperatorKeymapConfig: { [string]: occurrence.OperatorKeymapEntry }
---@class occurrence.OperatorKeymapOptions: { [string]?: occurrence.OperatorKeymapEntry }

---@class occurrence.Options
---@field actions? occurrence.KeymapOptions
---@field operators? occurrence.OperatorKeymapOptions
---@field preset_actions? occurrence.ActivePresetKeymapOptions

---@type occurrence.KeymapConfig
local DEFAULT_KEYMAP_CONFIG = {
  n = {
    go = "mark_search_or_word",
    -- go = "mark_word",
  },
  v = {
    go = "mark_selection",
  },
  o = {
    o = "modify_operator",
    -- oo = "modify_operator_linewise",
  },
}

---@type occurrence.OperatorKeymapConfig
local DEFAULT_OPERATOR_KEYMAP_CONFIG = {
  -- operators
  ["c"] = "change",
  ["d"] = "delete",
  ["y"] = "yank",
  ["<"] = "indent_left",
  [">"] = "indent_right",

  ["gu"] = {
    desc = "Make marked occurrences lowercase",
    method = "visual_feedkeys",
    uses_register = false,
    modifies_text = true,
  },
  ["gU"] = {
    desc = "Make marked occurrences uppercase",
    method = "visual_feedkeys",
    uses_register = false,
    modifies_text = true,
  },
  ["g~"] = {
    desc = "Swap case of marked occurrences",
    method = "visual_feedkeys",
    uses_register = false,
    modifies_text = true,
  },
  ["g?"] = {
    desc = "ROT13 encode marked occurrences",
    method = "visual_feedkeys",
    uses_register = false,
    modifies_text = true,
  },

  -- TODO: implement these
  ["p"] = false, -- put
  ["gq"] = false, -- text formatting
  ["gw"] = false, -- text formatting with no cursor movement
  ["zf"] = false, -- define a fold
  ["="] = false, -- filter through 'equalprg' or C-indenting if empty
  ["!"] = false, -- filter through an external program
  ["g@"] = false, -- call function set with 'operatorfunc'
}

---@type occurrence.ActivePresetKeymapConfig
local DEFAULT_ACTIVE_PRESET_KEYMAP_CONFIG = {
  n = {
    -- deactivate
    ["<Esc>"] = "deactivate",
    -- ["<C-c>"] = "deactivate",
    -- ["<C-[>"] = "deactivate",

    -- navigate
    n = "goto_next_mark",
    N = "goto_previous_mark",
    gn = "goto_next",
    gN = "goto_previous",

    -- mark/unmark
    go = "mark_word_or_toggle_mark",
    ga = "mark",
    gx = "unmark",

    -- operators
    -- TODO: implement these
    ["dd"] = false, -- delete line
    ["cc"] = false, -- change line
    ["yy"] = false, -- yank line
    ["C"] = false, -- change to end of line
    ["D"] = false, -- delete to end of line
    ["Y"] = false, -- yank to end of line
  },
  v = {
    -- mark/unmark
    go = "mark_selection_or_toggle_marks_in_selection",
    ga = "mark",
    gx = "unmark",
  },
}

local DEFAULT_CONFIG = {
  actions = DEFAULT_KEYMAP_CONFIG,
  operators = DEFAULT_OPERATOR_KEYMAP_CONFIG,
  preset_actions = DEFAULT_ACTIVE_PRESET_KEYMAP_CONFIG,
}

-- Default operator configuration that is used
-- when an operator is enabled with `true`.
---@type occurrence.OperatorConfig
local DEFAULT_OPERATOR_CONFIG = {
  method = "visual_feedkeys",
  uses_register = false,
  modifies_text = true,
}

---@param opts? occurrence.Options
---@param key string
---@return occurrence.KeymapConfig|occurrence.OperatorKeymapConfig|occurrence.ActivePresetKeymapConfig|nil
---@overload fun(opts: occurrence.Options?, key: "actions"): occurrence.KeymapConfig
---@overload fun(opts: occurrence.Options?, key: "operators"): occurrence.OperatorKeymapConfig
---@overload fun(opts: occurrence.Options?, key: "preset_actions"): occurrence.ActivePresetKeymapConfig
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

---Check if the given options is already a config.
---@param opts any
---@return boolean
local function is_config(opts)
  return type(opts) == "table" and type(opts.get) == "function" and type(opts.validate) == "function"
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

---@param key string
---@param actions_config occurrence.KeymapConfig
---@return string
local function resolve_action_key(key, actions_config)
  local resolved = actions_config[key]
  local seen = {}
  while type(resolved) == "string" do
    if seen[key] then
      error("Circular action alias detected: '" .. key .. "' <-> '" .. resolved .. "'")
    end
    seen[key] = true
    key = resolved
    resolved = actions_config[key]
  end
  return key
end

---@class occurrence.Config
---@field actions fun(self: occurrence.Config): occurrence.KeymapConfig
---@field operators fun(self: occurrence.Config): occurrence.OperatorKeymapConfig
---@field preset_actions fun(self: occurrence.Config): occurrence.ActivePresetKeymapConfig
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field get fun(self: occurrence.Config, key: string): occurrence.KeymapConfig|occurrence.OperatorKeymapConfig|occurrence.ActivePresetKeymapConfig|nil
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
---@param mode? occurrence.KeymapMode
---@return occurrence.ActionConfig | false | nil
function Config:get_action_config(name, mode)
  local actions = self:actions()
  local action_config = nil
  if mode ~= nil then
    if actions[mode] == nil then
      log.warn_once("Invalid mode: " .. tostring(mode))
      return
    end
    name = resolve_action_key(name, actions[mode])
    action_config = actions[mode][name]
  end
  if action_config == nil then
    local builtins = require("occurrence.actions")
    action_config = builtins[name]
  end
  return action_config
end

-- Wrap the given `action` in a function to be used as a keymap callback.
-- If `action` is a string, it will be resolved to a builtin action.
-- If `action` is a preset, operator, or operator-modifier config it will be created.
-- If `action` is a function, it will be treated as an action callback.
---@param action occurrence.KeymapAction
---@return function
function Config:wrap_action(action)
  ---@type { callback: occurrence.ActionCallback } | nil | false
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

  if action_config == false then
    error("Action " .. tostring(action) .. " is disabled")
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
      if key == "get" then
        return function(_, k)
          return get(opts, k)
        end
      end
      if Config[key] ~= nil then
        return Config[key]
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
