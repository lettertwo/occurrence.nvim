local api = require("occurrence.api")
local command = require("occurrence.command")
local resolve_buffer = require("occurrence.resolve_buffer")

-- Helper to convert snake_case to CapCase
local function to_capcase(snake_str)
  local result = snake_str:gsub("_(%w)", function(c)
    return c:upper()
  end)
  return result:sub(1, 1):upper() .. result:sub(2)
end

-- Global config set by setup(), can be nil
---@type occurrence.Config?
local _global_config = nil

---@class occurrence
-- Find occurrences of the word under the cursor, mark all matches,
-- and activate occurrence mode
---@field word fun(opts?: occurrence.Options): nil
-- Find occurrences of the current visual selection, mark all
-- matches, and activate occurrence mode
---@field selection fun(opts?: occurrence.Options): nil
-- Find occurrences of the last search pattern, mark all matches,
-- and activate occurrence mode
---@field pattern fun(opts?: occurrence.Options): nil
-- Smart entry action that adapts to the current context. In
-- visual mode: acts like `selection`. Otherwise, if `:h hlsearch`
-- is active: acts like `pattern`. Otherwise: acts like `word`.
-- Marks all matches and activates occurrence mode
---@field current fun(opts?: occurrence.Options): nil
-- Move to the next marked occurrence
---@field next fun(opts?: occurrence.Options): nil
-- Move to the previous marked occurrence
---@field previous fun(opts?: occurrence.Options): nil
-- Move to the next occurrence match, whether marked or unmarked
---@field match_next fun(opts?: occurrence.Options): nil
-- Move to the previous occurrence match, whether marked or unmarked
---@field match_previous fun(opts?: occurrence.Options): nil
-- Mark the occurrence match nearest to the cursor
---@field mark fun(opts?: occurrence.Options): nil
-- Unmark the occurrence match nearest to the cursor
---@field unmark fun(opts?: occurrence.Options): nil
-- Smart toggle action that activates occurrence mode or toggles
-- marks. In normal mode: If no patterns exist, acts like `word`
-- to start occurrence mode. Otherwise, toggles the mark on the
-- match under the cursor, or adds a new word pattern if not on a
-- match. In visual mode: If no patterns exist, acts like
-- `selection` to start occurrence mode. Otherwise, toggles marks
-- on all matches within the selection, or adds a new selection
-- pattern if no matches.
---@field toggle fun(opts?: occurrence.Options): nil
-- Mark all occurrence matches in the buffer
---@field mark_all fun(opts?: occurrence.Options): nil
-- Unmark all occurrence matches in the buffer
---@field unmark_all fun(opts?: occurrence.Options): nil
-- Mark all occurrence matches in the current visual selection
---@field mark_in_selection fun(opts?: occurrence.Options): nil
-- Unmark all occurrence matches in the current visual selection
---@field unmark_in_selection fun(opts?: occurrence.Options): nil
-- Clear all marks and patterns, and deactivate occurrence mode
---@field deactivate fun(opts?: occurrence.Options): nil
-- Modify a pending operator to act on occurrences of the word
-- under the cursor. Only useful in operator-pending mode
-- (e.g., `c`, `d`, etc.)
---@field modify_operator fun(opts?: occurrence.Options): nil
local occurrence = {}

-- Generate public API functions and commands for all api functions and
-- register <Plug> mappings for all commands using CapCase convention.
for name, api_config in pairs(api) do
  -- Create `occurrence.<name>` API function
  occurrence[name] = function(opts)
    -- TODO: explore passing args from commandline
    local config, _ = occurrence.parse_opts(opts)
    require("occurrence.Occurrence").get():apply(api_config, config)
  end

  -- Register `Occurrence <name>` subcommand
  command.add(name, { impl = occurrence[name] })

  -- Register `<Plug>(OccurrenceName)` keymap
  vim.keymap.set(
    api_config.mode or { "n", "v" },
    api_config.plug or ("<Plug>(Occurrence" .. to_capcase(name) .. ")"),
    occurrence[name],
    {
      desc = api_config.desc or ("Occurrence: " .. name),
      expr = api_config.expr or false,
      silent = true,
    }
  )
end

---Resolve config with priority: config param > setup(config) > default
---Note that options passed in as a param are not merged with config
---defined previously via `setup()`.
---@param config? occurrence.Options | occurrence.Config
---@return occurrence.Config
function occurrence.resolve_config(config)
  local Config = require("occurrence.Config")
  if config then
    return Config.new(config)
  end
  if _global_config then
    return _global_config
  end
  return Config.new()
end

-- Parse options table for API functions.
-- Note that `opts` may be string args coming from the command line.
---@param opts? occurrence.Options | occurrence.Config | string[]
---@return occurrence.Config
function occurrence.parse_opts(opts)
  if opts == nil or type(opts) ~= table or vim.tbl_isempty(opts) then
    return occurrence.resolve_config()
  elseif vim.islist(opts) then
    -- TODO: support string[] options
    error("Not implemented: string[] options are not supported yet")
  end
  return occurrence.resolve_config(opts)
end

-- Reset the occurrence plugin by removing keymaps
-- and cancelling active occurrences.
-- Automatically called by `setup({})`.
function occurrence.reset()
  _global_config = nil
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    require("occurrence.Occurrence").del(resolve_buffer(buffer))
  end
  -- Remove default keymaps if they exist
  for _, mode in ipairs({ "n", "v", "o" }) do
    local keymap = vim.api.nvim_get_keymap(mode)
    for _, km in ipairs(keymap) do
      if (km.lhs == "go" and km.rhs == api.current.plug) or (km.lhs == "o" and km.rhs == api.modify_operator.plug) then
        pcall(vim.keymap.del, mode, km.lhs)
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
function occurrence.setup(opts)
  if _global_config and opts == nil then
    return
  end
  opts = opts or {}
  local config = require("occurrence.Config").new(opts)
  if _global_config ~= config then
    if _global_config ~= nil then
      occurrence.reset()
    end
    _global_config = config
    -- Set up default keymaps if enabled
    if config.default_keymaps then
      -- Normal and visual mode default
      vim.keymap.set({ "n", "v" }, "go", api.current.plug, {
        desc = api.current.desc,
      })
      -- Operator-pending mode default
      vim.keymap.set("o", "o", api.modify_operator.plug, {
        desc = api.modify_operator.desc,
      })

      -- TODO: support inner and around occurrence operator modifiers
      -- vim.keymap.set("o", "io", api.modify_operator_inner.plug, {
      --   desc = api.modify_operator_inner.desc,
      -- })
      -- vim.keymap.set("o", "ao", api.modify_operator_around.plug, {
      --   desc = api.modify_operator_around.desc,
      -- })
    end
  end
end

-- Get occurrence count information for the current buffer.
-- Similar to `:h searchcount()` but for occurrence matches.
-- Returns the position of the cursor within matches and the total count.
-- If `marked` is `true`, only marked occurrences will be counted.
-- If `buffer` is provided, it will be used instead of the current buffer.
---@param opts? { marked?: boolean, buffer?: integer }
---@return occurrence.Status | nil `nil` if there is no active occurrence for the buffer.
function occurrence.status(opts)
  opts = opts or {}
  local buffer = opts.buffer or vim.api.nvim_get_current_buf()

  local occ = require("occurrence.Occurrence").get(buffer)
  if not occ or occ:is_disposed() or #occ.patterns == 0 then
    return nil
  end

  return occ:status({ marked = opts.marked })
end

-- Create the main Occurrence command with subcommands
vim.api.nvim_create_user_command("Occurrence", command.execute, {
  nargs = "+",
  desc = "Occurrence command",
  force = true,
  complete = command.complete,
  preview = command.preview,
})

return occurrence
