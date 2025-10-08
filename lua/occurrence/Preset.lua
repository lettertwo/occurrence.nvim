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

-- Helper to convert snake_case to CapCase for <Plug> names
local function to_capcase(snake_str)
  local result = snake_str:gsub("_(%w)", function(c)
    return c:upper()
  end)
  return result:sub(1, 1):upper() .. result:sub(2)
end

local DEFAULT_PRESET_KEYMAP = {
  n = {
    ["<Esc>"] = "deactivate",
    n = "goto_next_mark",
    N = "goto_previous_mark",
    gn = "goto_next",
    gN = "goto_previous",
    go = "mark_word_or_toggle_mark",
    ga = "mark",
    gx = "unmark",
  },
  v = {
    go = "toggle_selection",
  },
}

---@param occurrence occurrence.Occurrence
---@param config occurrence.Config
local function activate_preset(occurrence, config)
  local buffer = occurrence.buffer

  if config.on_preset_activate then
    -- Call user callback with keymap setter
    config:on_preset_activate(function(mode, lhs, rhs, opts)
      opts = vim.tbl_extend("force", opts or {}, { buffer = buffer })
      occurrence.keymap:set(mode, lhs, rhs, opts)
    end)
  elseif config.default_keymaps then
    -- Use default keymaps

    -- Disable the default operator-pending mapping.
    -- Note that this isn't strictly necessary, since the modify operator
    -- command is a no-op when there is a preset keymap active,
    -- but it gives some descriptive feedback to the user to update the binding.
    occurrence.keymap:set("o", "o", "<Nop>")

    -- Set up buffer-local keymaps for normal mode preset actions
    local api = require("occurrence.api")
    for key, action_name in pairs(DEFAULT_PRESET_KEYMAP.n) do
      local capcase = to_capcase(action_name)
      local action_config = api[action_name]
      local desc = action_config and action_config.desc or ("Occurrence: " .. action_name)
      occurrence.keymap:set("n", key, "<Plug>Occurrence" .. capcase, { desc = desc })
    end

    -- Set up buffer-local keymaps for visual mode preset actions
    for key, action_name in pairs(DEFAULT_PRESET_KEYMAP.v) do
      local capcase = to_capcase(action_name)
      local action_config = api[action_name]
      local desc = action_config and action_config.desc or ("Occurrence: " .. action_name)
      occurrence.keymap:set("v", key, "<Plug>Occurrence" .. capcase, { desc = desc })
    end

    -- Set up buffer-local keymaps for operators
    for operator_key in pairs(config:operators()) do
      local operator_config = config:get_operator_config(operator_key)
      local operator = operator_config and Operator.new(operator_key, operator_config)

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
end

---@param config occurrence.PresetConfig
---@param occurrence_config occurrence.Config
---@return function
local function create_preset(config, occurrence_config)
  return function()
    local occurrence = Occurrence.get()

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

    if not occurrence.keymap:is_active() then
      log.debug("Activating preset keymaps for buffer", occurrence.buffer)
      activate_preset(occurrence, occurrence_config)
    end
  end
end

return {
  new = create_preset,
  is = is_preset,
  activate = activate_preset,
}
