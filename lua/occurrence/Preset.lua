local Cursor = require("occurrence.Cursor")
local Keymap = require("occurrence.Keymap")
local Occurrence = require("occurrence.Occurrence")
local Operator = require("occurrence.Operator")
local Range = require("occurrence.Range")

local log = require("occurrence.log")
local set_opfunc = require("occurrence.set_opfunc")

---@module "occurrence.Preset"

-- Function to be used as a callback for a preset action.
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
-- If the function returns `false`, the preset activation will be cancelled.
---@alias occurrence.PresetCallback fun(occurrence: occurrence.Occurrence, config: occurrence.Config): false | nil

-- An action that will activate preset keymaps after running.
---@class (exact) occurrence.PresetConfig
---@field type "preset"
---@field desc? string
---@field callback? occurrence.PresetCallback

---@param candidate any
---@return boolean
local function is_preset(candidate)
  return type(candidate) == "table" and candidate.type == "preset"
end

-- Cache of activated presets to avoid re-creating keymaps.
---@type table<occurrence.Occurrence, occurrence.Keymap>
local PRESET_CACHE = setmetatable({}, { __mode = "k" })

---@param occurrence occurrence.Occurrence
---@param occurrence_config occurrence.Config
---@return occurrence.Keymap
local function activate_preset(occurrence, occurrence_config)
  local preset_actions = occurrence_config:preset_actions()
  local keymap = Keymap.new(occurrence.buffer, occurrence_config)
  keymap:map_preset_actions("n")
  keymap:map_preset_actions("v")

  for operator_key in pairs(occurrence_config:operators()) do
    local operator_config = occurrence_config:get_operator_config(operator_key)
    local operator = operator_config and Operator.new(operator_key, operator_config, occurrence_config)

    -- Add normal operator keymap (unless overridden or disabled)
    if operator and not preset_actions.n[operator_key] and preset_actions.n[operator_key] ~= false then
      local desc = "'" .. operator_key .. "' on marked occurrences"
      if type(operator_config) == "table" and operator_config.desc then
        desc = operator_config.desc
      end

      keymap:n(operator_key, operator, { desc = desc, expr = true })
    else
      log.debug("Skipping operator key:", operator_key, "as it is disabled in the config")
    end

    -- Add visual operator keymap (unless overridden or disabled)
    if operator and not preset_actions.v[operator_key] and preset_actions.v[operator_key] ~= false then
      local desc = "'" .. operator_key .. "' on marked occurrences in selection"
      if type(operator_config) == "table" and operator_config.desc then
        desc = operator_config.desc .. " in selection"
      end

      keymap:v(operator_key, operator, { desc = desc })
    else
      log.debug("Skipping operator key:", operator_key, "as it is disabled in the config")
    end
  end

  return keymap
end

---@param config occurrence.PresetConfig
---@param occurrence_config occurrence.Config
---@return function
local function create_preset(config, occurrence_config)
  return function()
    local occurrence = Occurrence.get()
    local keymap = PRESET_CACHE[occurrence]

    local ok, result = pcall(config.callback, occurrence, occurrence_config)
    if ok and result == false then
      log.debug("Preset action cancelled")
      if keymap then
        keymap:reset()
        PRESET_CACHE[occurrence] = nil
      end
      return
    end

    if not occurrence:has_matches() then
      log.warn("No matches found for pattern(s):", table.concat(occurrence.patterns, ", "), "skipping activation")
      if keymap then
        keymap:reset()
        PRESET_CACHE[occurrence] = nil
      end
      return
    end

    if not keymap then
      log.debug("Activating preset keymaps for buffer", occurrence.buffer)
      keymap = activate_preset(occurrence, occurrence_config)
      PRESET_CACHE[occurrence] = keymap
    end
  end
end

return {
  new = create_preset,
  is = is_preset,
  activate = activate_preset,
}
