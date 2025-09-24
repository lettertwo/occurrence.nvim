local Keymap = require("occurrence.Keymap")
local Occurrence = require("occurrence.Occurrence")
local Operator = require("occurrence.Operator")

local log = require("occurrence.log")

---@module "occurrence.Preset"

-- Function to be used as a callback for a preset action.
-- The first argument will always be the `Occurrence` for the current buffer.
-- If the function returns `false`, the preset activation will be cancelled.
---@alias occurrence.PresetCallback fun(occurrence: occurrence.Occurrence): false | nil

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

---@param keymap occurrence.BufferKeymap
---@param config occurrence.Config
local function activate_preset(keymap, config)
  local preset_actions = config:preset_actions()
  keymap:map_preset_actions("n", config)
  keymap:map_preset_actions("v", config)

  for operator_key in pairs(config:operators()) do
    local operator_config = config:get_operator_config(operator_key)
    local operator = operator_config and Operator.new(operator_key, operator_config)

    -- Add normal operator keymap (unless overridden or disabled)
    if operator and not preset_actions.n[operator_key] and preset_actions.n[operator_key] ~= false then
      local desc = "'" .. operator_key .. "' on marked occurrences"
      if type(operator_config) == "table" and operator_config.desc then
        desc = operator_config.desc
      end

      keymap:n(operator_key, operator, { desc = desc, expr = true }, config)
    else
      log.debug("Skipping operator key:", operator_key, "as it is disabled in the config")
    end

    -- Add visual operator keymap (unless overridden or disabled)
    if operator and not preset_actions.v[operator_key] and preset_actions.v[operator_key] ~= false then
      local desc = "'" .. operator_key .. "' on marked occurrences in selection"
      if type(operator_config) == "table" and operator_config.desc then
        desc = operator_config.desc .. " in selection"
      end

      keymap:v(operator_key, operator, { desc = desc }, config)
    else
      log.debug("Skipping operator key:", operator_key, "as it is disabled in the config")
    end
  end
end

---@param config occurrence.PresetConfig
---@param occurrence_config occurrence.Config
---@return function
local function create_preset(config, occurrence_config)
  return function()
    local occurrence = Occurrence.new()

    local ok, result = pcall(config.callback, occurrence, occurrence_config)
    if not ok or result == false then
      log.debug("Preset action cancelled")
      occurrence:dispose()
      return
    end

    if not occurrence:has_matches() then
      log.warn("No matches found for pattern(s):", table.concat(occurrence.patterns, ", "), "skipping activation")
      occurrence:dispose()
      return
    end

    if not occurrence:has_active_keymap() then
      log.debug("Activating preset keymaps for buffer", occurrence.buffer)
      activate_preset(occurrence.keymap, occurrence_config)
    end
  end
end

return {
  new = create_preset,
  is = is_preset,
  activate = activate_preset,
}
