local api = require("occurrence.api")
local command = require("occurrence.command")
local resolve_buffer = require("occurrence.resolve_buffer")

-- Global config set by setup(), can be nil
---@type occurrence.Config?
local _global_config = nil

---@type [string|string[], string, string, table][]
local DEFAULT_GLOBAL_KEYMAPS = {
  -- Normal and visual mode default
  { { "n", "v" }, "go", api.mark.plug, { desc = api.mark.desc } },
  -- Operator-pending mode default
  { "o", "o", api.modify_operator.plug, { desc = api.modify_operator.desc } },
  -- TODO: support inner and around occurrence operator modifiers
  -- { "o", io", api.modify_operator_inner.plug, { desc = api.modify_operator_inner.desc } },
  -- { "o","ao", api.modify_operator_around.plug, { desc = api.modify_operator_around.desc } },
}

---@class occurrence
--
-- Modify a pending operator to act on occurrences of the word
-- under the cursor. Only useful in operator-pending mode
-- (e.g., `c`, `d`, etc.)
--
-- Once a pending operator is modified, the operator will act
-- on occurrences within the range specified by the subsequent motion.
--
-- Note that this action does not activate occurrence mode,
-- and it does not have any effect when occurrence mode is active,
-- as operators already act on occurrences in that mode.
---@field modify_operator fun(opts?: occurrence.Options): nil
--
-- Mark one or more occurrences and activate occurrence mode.
--
-- If occurrence already has matches, mark matches based on:
-- - In visual mode, if matches exist in the range of the visual
--   selection, mark those matches.
-- - Otherwise, if a match exists at the cursor, mark that match.
--
-- If no occurrence match exists to satisfy the above, add a new pattern based on:
--   - In visual mode, mark occurrences of the visual selection.
--   - If `:h hlsearch` is active, mark occurrences of the search pattern.
--   - Otherwise, mark occurrences of the word under the cursor.
---@field mark fun(opts?: occurrence.Options): nil
--
-- Unmark one or more occurrences.
--
-- If occurrence has matches, unmark matches based on:
-- - In visual mode, unmark matches in the range of the visual selection.
-- - Otherwise, if a match exists at the cursor, unmark that match.
--
-- If no match exists to satisfy the above, does nothing.
---@field unmark fun(opts?: occurrence.Options): nil
--
-- Mark or unmark one (or more) occurrence(s) and activate occurrence mode.
--
-- If occurrence already has matches, toggle matches based on:
-- - In visual mode, if matches exist in the range of the visual
--   selection, toggle marks on those matches.
-- - Otherwise, if a match exists at the cursor, toggle that mark.
--
-- If no occurrence match exists to satisfy the above, add a new pattern based on:
--   - In visual mode, mark the closest occurrence of the visual selection.
--   - If `:h hlsearch` is active, mark the closest occurrence of the search pattern.
--   - Otherwise, mark the closest occurrence of the word under the cursor.
---@field toggle fun(opts?: occurrence.Options): nil
--
-- Move to the next marked occurrence and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the next marked occurrence.
---@field next fun(opts?: occurrence.Options): nil
--
-- Move to the previous marked occurrence and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the previous marked occurrence.
---@field previous fun(opts?: occurrence.Options): nil
--
-- Move to the next occurrence match, whether marked or unmarked,
-- and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the next occurrence match.
---@field match_next fun(opts?: occurrence.Options): nil
--
-- Move to the previous occurrence match, whether marked or unmarked,
-- and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the previous occurrence match.
---@field match_previous fun(opts?: occurrence.Options): nil
--
-- Clear all marks and patterns, and deactivate occurrence mode.
---@field deactivate fun(opts?: occurrence.Options): nil
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

  if api_config.plug ~= nil then
    -- Register `<Plug>(OccurrenceName)` keymap
    vim.keymap.set(api_config.mode or { "n", "v" }, api_config.plug, occurrence[name], {
      desc = api_config.desc or ("Occurrence: " .. name),
      expr = api_config.expr or false,
      silent = true,
    })
  end
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
  local prev_config = _global_config
  _global_config = nil
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    require("occurrence.Occurrence").del(resolve_buffer(buffer))
  end
  -- Remove default keymaps if they exist
  if prev_config and prev_config.default_keymaps then
    for _, keymap in ipairs(DEFAULT_GLOBAL_KEYMAPS) do
      local mode, lhs, _, opts = unpack(keymap)
      vim.keymap.del(mode, lhs, opts)
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
  if _global_config and (opts == nil or vim.tbl_isempty(opts)) then
    return -- No-op if already configured and no new opts provided
  end
  local config = require("occurrence.Config").new(opts)
  if _global_config ~= config then
    if _global_config ~= nil then
      occurrence.reset()
    end
    _global_config = config
    -- Set up default keymaps if enabled
    if config.default_keymaps then
      for _, keymap in ipairs(DEFAULT_GLOBAL_KEYMAPS) do
        vim.keymap.set(unpack(keymap))
      end
    end

    -- Create the main Occurrence command with subcommands
    vim.api.nvim_create_user_command("Occurrence", command.execute, {
      nargs = "+",
      desc = "Occurrence command",
      force = true,
      complete = command.complete,
      preview = command.preview,
    })
  end
end

-- Get the Occurrence instance for the given buffer.
-- If `buffer` is not provided, the current buffer will be used.
---@param buffer? integer
---@return occurrence.Occurrence | nil `nil` if there is no active occurrence for the buffer.
function occurrence.get(buffer)
  return require("occurrence.Occurrence").get(buffer)
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

  local occ = occurrence.get(opts.buffer)
  if not occ or occ:is_disposed() or #occ.patterns == 0 then
    return nil
  end

  return occ:status({ marked = opts.marked })
end

return occurrence
