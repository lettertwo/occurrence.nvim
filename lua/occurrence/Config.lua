local log = require("occurrence.log")

-- Global config set by setup(), can be nil
---@type occurrence.Config?
local _global_config = nil

-- Function to be used as a callback for a keymap
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
-- If the function returns `false`, the occurrence will be disposed.
---@alias occurrence.KeymapCallback fun(occurrence: occurrence.Occurrence, args?: occurrence.SubcommandArgs): false?

-- A configuration for an occurrence mode keymap.
-- A keymap defined this way will be buffer-local and
-- active only when occurrence mode is active.
---@class (exact) occurrence.KeymapConfig
-- The callback function to invoke when the keymap is triggered.
---@field callback occurrence.KeymapCallback
-- The mode(s) in which the keymap is active.
-- Note that, regardless of these modes, the keymap will
-- only be active when occurrence mode is active.
---@field mode? "n" | "v" | ("n" | "v")[]
-- An optional description for the keymap.
-- Similar to the `desc` field in `:h vim.keymap.set` options.
---@field desc? string

-- A configuration for a global keymap that will exit operator_pending mode,
-- set occurrences of the current word and then re-enter operator-pending mode
-- with `:h opfunc`.
---@class (exact) occurrence.OperatorModifierConfig: occurrence.KeymapConfig
---@field type "operator-modifier"
---@field mode "o"
---@field expr true
---@field plug string
---@field default_global_key string?

-- A configuration for a global keymap that will run and then
-- activate occurrence mode keymaps, if not already active.
---@class (exact) occurrence.OccurrenceModeConfig: occurrence.KeymapConfig
---@field type "occurrence-mode"
---@field plug string
---@field default_global_key string?

---@class (exact) occurrence.OperatorCurrent
---@field id number The extmark id for the occurrence
---@field index number 1-based index of the occurrence
---@field range occurrence.Range The range of the occurrence
---@field text string[] The text of the occurrence as a list of lines

---@class (exact) occurrence.OperatorContext: { [string]: any }
---@field occurrence occurrence.Occurrence
---@field marks [number, occurrence.Range][]
---@field mode 'n' | 'v' | 'o' The mode from which the operator is being triggered.
---@field register? occurrence.Register The register being used for the operation.

-- A function to be used as an operator on marked occurrences.
-- The function will be called for each marked occurrence with the following arguments:
--  - `current`: a table representing the occurrence currently being processed:
--    - `id`: the extmark id for the occurrence
--    - `index`: the index of the occurrence among all marked occurrences to be processed
--    - `range`: a table representing the range of the occurrence (see `occurrence.OccurrenceRange`)
--    - `text`: the text of the occurrence as a list of lines
--  - `ctx`: a table containing context for the operation:
--    - `occurrence`: the active occurrence state for the buffer (see `occurrence.Occurrence`)
--    - `marks`: a list of all marked occurrences as `[id, range]` tuples
--    - `mode`: the mode from which the operator is being triggered ('n', 'v', or 'o')
--    - `register`: the register being used for the operation (see `occurrence.Register`)
-- The `ctx` may also be used to store state between calls for each occurrence.
--
-- The function should return either:
--   - `string | string[]` to replace the occurrence text
--   - `nil | true` to leave the occurrence unchanged and proceed to the next occurrence
--   - `false` to cancel the operation on this and all remaining occurrences
--
--  If the return value is truthy (not `nil | false`), the original text
--  of the occurrence will be yanked to the register specified in `ctx.register`.
--  To prevent this, set `ctx.register` to `nil`.
---@alias occurrence.OperatorFn fun(mark: occurrence.OperatorCurrent, ctx: occurrence.OperatorContext): string | string[] | boolean | nil

-- A configuration for a keymap that will run an operation
-- on occurrences either as part of modifying a pending operator,
-- or when occurrence mode is active.
---@class (exact) occurrence.OperatorConfig
-- The operatation to perform on each marked occcurence. Either:
--   - a key sequence (e.g., `"gU"`) to be applied to the visual selection of each marked occurrence,
--   - or a function that will be called for each marked occurrence.
---@field operator string | occurrence.OperatorFn
-- The mode(s) in which the operator keymap is active.
-- Note that:
--  - if "n" or "v" are included, the keymap will
--    only be active when occurrence mode is active.
--  - if "o" is included, a pending operator matching this keymap
--    can be modified to operate on occurrences.
-- Defaults to `{ "n", "v", "o" }`.
---@field mode? "n" | "v" | "o" | ("n" | "v" | "o")[]
-- An optional description for the keymap.
-- Similar to the `desc` field in `:h vim.keymap.set` options.
---@field desc? string
-- Whether to operate on the inner range of the occurrence only.
-- Setting this to `false` will include surrounding whitespace,
-- similar to the difference between `iw` and `aw` text objects.
-- Default is `true`.
---@field inner? boolean

-- Internal descriptor for actions
---@alias occurrence.ApiConfig
---   | occurrence.OccurrenceModeConfig
---   | occurrence.OperatorModifierConfig
---   | occurrence.OperatorConfig

---@alias occurrence.OperatorKeymapEntry occurrence.OperatorConfig | occurrence.BuiltinOperator | string | false
---@alias occurrence.OperatorKeymapConfig { [string]: occurrence.OperatorKeymapEntry }

---@alias occurrence.OccurrenceModeKeymapEntry occurrence.KeymapConfig | occurrence.KeymapAction | string | false
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
-- e.g., `vim.keymap.set("n", "<leader>o", "<Plug>(OccurrenceMark)")``
-- or `vim.keymap.set("o", "<C-o>", "<Plug>(OccurrenceModifyOperator)")`.
--
-- Additionally, when `false`, only keymaps explicitly defined in `keymaps`
-- will be automatically set when activating occurrence mode. Keymaps for
-- occurrence mode can also be set manually in an `OccurrenceActivate`
-- autocmd using `occurrence.keymap:set(...)`.
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

---@type { [string]: occurrence.KeymapAction }
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
}

---@param value occurrence.OperatorConfig
local function validate_operator_config(value)
  vim.validate("config", value, "table")
  vim.validate("operator", value.operator, { "callable", "string" })
  if value.mode then
    vim.validate("mode", value.mode, { "string", "table" }, true)
  end
  vim.validate("desc", value.desc, "string", true)
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
    local keymaps = require("occurrence.api")
    keymap_config = keymaps[name]
    ---@cast keymap_config -occurrence.KeymapAction
  end

  -- Validate user-provided keymap config, but not built-in configs
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

---@param key string
---@return string
function Config:resolve_operator_key(key)
  local resolved = self.operators[key]
  local seen = {}
  while type(resolved) == "string" do
    if seen[key] then
      error("Circular operator alias detected: '" .. key .. "' <-> '" .. resolved .. "'")
    end
    seen[key] = true
    key = resolved
    resolved = self.operators[key]
  end
  return key
end

---@param name string
---@param mode? "n" | "v" | "o"
---@return occurrence.OperatorConfig | nil
function Config:get_operator_config(name, mode)
  local operator_config = nil
  name = self:resolve_operator_key(name)
  operator_config = self.operators[name]
  -- Explicitly disabled operator
  if operator_config == false then
    return nil
  end

  if type(operator_config) == "string" then
    name = self:resolve_operator_key(operator_config)
    operator_config = self.operators[name]
    ---@cast operator_config -string
  end

  if operator_config == nil then
    local builtins = require("occurrence.api")
    operator_config = builtins[name]
    ---@cast operator_config -occurrence.BuiltinOperator
  end

  if operator_config ~= nil then
    local ok, err = pcall(validate_operator_config, operator_config)
    if not ok then
      log.warn_once(string.format("Invalid operator config for '%s': %s", name, err))
      return nil
    end

    -- Validate mode if provided
    if mode ~= nil then
      if type(operator_config.mode) == "string" then
        if operator_config.mode ~= mode then
          return nil
        end
      elseif type(operator_config.mode) == "table" then
        ---@diagnostic disable-next-line: param-type-mismatch
        if not vim.tbl_contains(operator_config.mode, mode) then
          return nil
        end
      end
    end
  end

  return operator_config
end

---@param name string
---@param mode? "n" | "v" | "o"
---@return boolean
function Config:operator_is_supported(name, mode)
  return not not self:get_operator_config(name, mode)
end

---@module 'occurrence.Config'
local config = {}

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

---Resolve config with priority: config param > setup(config) > default
---Note that options passed in as a param are not merged with config
---defined previously via `setup()`.
---@param options? occurrence.Options | occurrence.Config
---@return occurrence.Config
function config.get(options)
  if options then
    return config.new(options)
  end
  if _global_config then
    return _global_config
  end
  return config.new()
end

-- Reset the occurrence config by removing keymaps
-- and cancelling active occurrences.
-- Automatically called by `setup({})`.
function config.reset()
  local prev_config = _global_config
  _global_config = nil
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    require("occurrence.Occurrence").del(require("occurrence.resolve_buffer")(buffer))
  end

  -- Remove default keymaps if they exist
  for _, api_config in pairs(require("occurrence.api")) do
    if api_config.plug ~= nil and api_config.default_global_key ~= nil then
      local key = api_config.default_global_key
      local mode = api_config.mode or { "n", "v" }
      if type(mode) == "string" then
        mode = { mode }
      end

      for _, m in ipairs(mode) do
        local mappings = nil
        if m == "n" then
          mappings = vim.api.nvim_get_keymap("n")
        elseif m == "v" then
          mappings = vim.api.nvim_get_keymap("v")
        elseif m == "o" then
          mappings = vim.api.nvim_get_keymap("o")
        end

        if mappings ~= nil then
          for _, map in ipairs(mappings) do
            if map.lhs == key and map.rhs == api_config.plug then
              pcall(vim.keymap.del, m, key, { desc = api_config.desc })
            end
          end
        end
      end
    end
  end
end

-- Sets up `occurrence.nvim` using the given `opts`.
--
-- It is only necessary to call `setup()` if you intend
-- to customize the default configuration.
--
-- Any `opts` will be merged with the default config.
--
-- `setup()` may be called multiple times to reset the plugin
-- with a new configuration. Note that calling setup with no `opts`
-- is only effective the first time; Subsequent calls
-- do nothing unless called with new `opts`.
---@param opts? occurrence.Options
function config.setup(opts)
  if _global_config and (opts == nil or vim.tbl_isempty(opts)) then
    return -- No-op if already configured and no new opts provided
  end
  local new_config = require("occurrence.Config").new(opts)
  if _global_config ~= new_config then
    config.reset()
    _global_config = new_config
    -- Set up default keymaps if enabled
    if new_config.default_keymaps then
      for _, api_config in pairs(require("occurrence.api")) do
        if api_config.plug ~= nil and api_config.default_global_key ~= nil then
          local plug = api_config.plug
          local key = api_config.default_global_key
          local mode = api_config.mode or { "n", "v" }
          vim.keymap.set(mode, key, plug, { desc = api_config.desc })
        end
      end
    end
  end
end

return config
