local log = require("occurrence.log")

---@module 'occurrence.Config'
local config = {}

---@alias occurrence.KeymapAction occurrence.Action | occurrence.SupportedActions | false

---@class occurrence.KeymapConfig
---@field n { [string]: occurrence.KeymapAction } normal mode keymaps
---@field v { [string]: occurrence.KeymapAction } visual mode keymaps
---@field o { [string]: occurrence.KeymapAction } operator-pending mode keymaps

---@class occurrence.KeymapOptions
---@field n? { [string]?: occurrence.KeymapAction } normal mode keymaps
---@field v? { [string]?: occurrence.KeymapAction } visual mode keymaps
---@field o? { [string]?: occurrence.KeymapAction } operator-pending mode keymaps

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.SupportedOperators | false
---@class occurrence.OperatorKeymapConfig: { [string]: occurrence.OperatorKeymapEntry }
---@class occurrence.OperatorKeymapOptions: { [string]?: occurrence.OperatorKeymapEntry }

---@alias occurrence.ActivePresetKeymapAction occurrence.Action | occurrence.SupportedActions | occurrence.SupportedOperators | false

---@class occurrence.ActivePresetKeymapConfig
---@field n { [string]: occurrence.KeymapAction } normal mode keymaps
---@field v { [string]: occurrence.KeymapAction } visual mode keymaps

---@class occurrence.ActivePresetKeymapOptions
---@field n? { [string]?: occurrence.KeymapAction } normal mode keymaps
---@field v? { [string]?: occurrence.KeymapAction } visual mode keymaps

---@class occurrence.Options
---@field actions? occurrence.KeymapOptions
---@field operators? occurrence.OperatorKeymapOptions
---@field preset_actions? occurrence.ActivePresetKeymapOptions

---@type occurrence.KeymapConfig
local DEFAULT_KEYMAP_CONFIG = {
  n = {
    go = "activate_preset_with_search_or_cursor_word",
    -- go = "activate_preset_with_cursor_word",
  },
  v = {
    go = "activate_preset_with_selection",
  },
  o = {
    o = "modify_operator_pending",
    oo = "modify_operator_pending_linewise",
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
    uses_register = false,
    modifies_text = true,
    method = "visual_feedkeys",
  },
  ["gU"] = {
    desc = "Make marked occurrences uppercase",
    uses_register = false,
    modifies_text = true,
    method = "visual_feedkeys",
  },
  ["g~"] = {
    desc = "Swap case of marked occurrences",
    uses_register = false,
    modifies_text = true,
    method = "visual_feedkeys",
  },
  ["g?"] = {
    desc = "ROT13 encode marked occurrences",
    uses_register = false,
    modifies_text = true,
    method = "visual_feedkeys",
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
    go = "mark_cursor_word_or_toggle_mark",
    ga = "mark_cursor_word",
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
    go = "mark_selection_or_toggle_marks",
    ga = "mark_selection",
    gx = "unmark",
  },
}

local DEFAULT_CONFIG = {
  actions = DEFAULT_KEYMAP_CONFIG,
  operators = DEFAULT_OPERATOR_KEYMAP_CONFIG,
  preset_actions = DEFAULT_ACTIVE_PRESET_KEYMAP_CONFIG,
}

---@class occurrence.Config
---@field actions fun(self: occurrence.Config): occurrence.KeymapConfig
---@field operators fun(self: occurrence.Config): occurrence.OperatorKeymapConfig
---@field preset_actions fun(self: occurrence.Config): occurrence.ActivePresetKeymapConfig
---@field validate fun(self: occurrence.Config, opts: occurrence.Options): string? error_message
---@field get fun(self: occurrence.Config, key: string): occurrence.KeymapConfig|occurrence.OperatorKeymapConfig|occurrence.ActivePresetKeymapConfig|nil
local Config = {}

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

---Get a copy of the default configuration.
function config.default()
  return vim.deepcopy(DEFAULT_CONFIG)
end

---Check if the given options is already a config.
---@param opts any
---@return boolean
local function is_config(opts)
  return type(opts) == "table" and type(opts.get) == "function" and type(opts.validate) == "function"
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
