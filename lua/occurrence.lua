local api = require("occurrence.api")

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
---@field modify_operator fun(args?: occurrence.SubcommandArgs): nil
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
---@field mark fun(args?: occurrence.SubcommandArgs): nil
--
-- Unmark one or more occurrences.
--
-- If occurrence has matches, unmark matches based on:
-- - In visual mode, unmark matches in the range of the visual selection.
-- - Otherwise, if a match exists at the cursor, unmark that match.
--
-- If no match exists to satisfy the above, does nothing.
---@field unmark fun(args?: occurrence.SubcommandArgs): nil
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
---@field toggle fun(args?: occurrence.SubcommandArgs): nil
--
-- Move to the next marked occurrence and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the next marked occurrence.
---@field next fun(args?: occurrence.SubcommandArgs): nil
--
-- Move to the previous marked occurrence and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the previous marked occurrence.
---@field previous fun(args?: occurrence.SubcommandArgs): nil
--
-- Move to the next occurrence match, whether marked or unmarked,
-- and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the next occurrence match.
---@field match_next fun(args?: occurrence.SubcommandArgs): nil
--
-- Move to the previous occurrence match, whether marked or unmarked,
-- and activate occurrence mode.
--
-- If occurrence has no matches, acts like `mark`
-- and then moves to the previous occurrence match.
---@field match_previous fun(args?: occurrence.SubcommandArgs): nil
--
-- Clear all marks and patterns, and deactivate occurrence mode.
---@field deactivate fun(args?: occurrence.SubcommandArgs): nil
--
-- Change marked occurrences (may prompt for replacement)
---@field change fun(args?: occurrence.SubcommandArgs):nil
--
-- Delete marked occurrence
---@field delete fun(args?: occurrence.SubcommandArgs):nil
--
-- Distribute lines from register cyclically across marked occurrences.
-- If no register is specified, use the unnamed register.
---@field distribute fun(args?: occurrence.SubcommandArgs):nil
--
-- Format marked occurrences through `:h equalprg`
---@field indent_format fun(args?: occurrence.SubcommandArgs):nil
--
-- Indent marked occurrences to the left
---@field indent_left fun(args?: occurrence.SubcommandArgs):nil
--
-- Indent marked occurrences to the right
---@field indent_right fun(args?: occurrence.SubcommandArgs):nil
--
-- Convert marked occurrences to lowercase
---@field lowercase fun(args?: occurrence.SubcommandArgs):nil
--
-- Put text from register at each marked occurrence.
-- If no register is specified, use the unnamed register.
---@field put fun(args?: occurrence.SubcommandArgs):nil
--
-- Swap case of marked occurrences
---@field swap_case fun(args?: occurrence.SubcommandArgs):nil
--
-- Convert marked occurrences to uppercase
---@field uppercase fun(args?: occurrence.SubcommandArgs):nil
--
-- Yank marked occurrences into register.
-- If no register is specified, use the unnamed register.
---@field yank fun(args?: occurrence.SubcommandArgs):nil
local occurrence = {}

-- Create stubs for `occurrence.<name>` API functions
setmetatable(occurrence, {
  __index = function(_, name)
    local api_config = assert(api[name], "Missing occurrence API function: " .. name)
    ---@param args? occurrence.SubcommandArgs
    local impl = function(args)
      ---@diagnostic disable-next-line: redefined-local
      local args, config = occurrence.parse_args(args)
      require("occurrence.Occurrence").get():apply(api_config, args, config)
    end
    -- replace the stub with the actual implementation
    rawset(occurrence, name, impl)
    return impl
  end,
})

-- Create stubs to lazily initialize <Plug> keymaps.
for name, api_config in pairs(api) do
  if api_config.plug ~= nil then
    local mode = api_config.mode or { "n", "v" }
    local opts = {
      desc = api_config.desc,
      expr = api_config.expr,
      silent = true,
    }

    vim.keymap.set(mode, api_config.plug, function(...)
      local impl = occurrence[name]
      -- replace the stub with the actual implementation
      vim.keymap.set(mode, api_config.plug, impl, opts)
      return occurrence[name](...)
    end, opts)

    if vim.g.occurrence_auto_setup ~= false then
      -- Set any default global keymaps
      if api_config.default_global_key ~= nil then
        vim.keymap.set(mode, api_config.default_global_key, api_config.plug, { desc = api_config.desc })
      end
    end
  end
end

-- Create the main `:Occurrence` command with subcommands
local function init_command()
  local command = require("occurrence.command")
  -- Generate subcommands for all api functions
  for name in pairs(api) do
    command.add(name, { impl = occurrence[name] })
  end
  vim.api.nvim_create_user_command("Occurrence", command.execute, {
    nargs = "+",
    range = 0,
    force = true,
    desc = "Occurrence command",
    complete = command.complete,
  })
  return command
end

-- Create a stub to lazily initialize the command on first use.
vim.api.nvim_create_user_command("Occurrence", function(...)
  return init_command().execute(...)
end, {
  nargs = "+",
  range = 0,
  force = true,
  desc = "Occurrence command",
  complete = function(...)
    return init_command().complete(...)
  end,
})

-- Parse args table for API functions.
-- Note that `args` may be string args coming from the command line.
---@param args? occurrence.Options | occurrence.Config | occurrence.SubcommandArgs
---@return occurrence.SubcommandArgs?, occurrence.Config
function occurrence.parse_args(args)
  if
    args == nil
    or type(args) ~= table
    or vim.tbl_isempty(args)
    or vim.islist(args)
    or args.count ~= nil
    or args.range ~= nil
  then
    ---@cast args -occurrence.Options, -occurrence.Config
    return args, require("occurrence.Config").get()
  end
  ---@cast args -occurrence.SubcommandArgs
  return nil, require("occurrence.Config").get(args)
end

-- Get the Occurrence instance for the given buffer.
-- If `buffer` is not provided, the current buffer will be used.
---@param buffer? integer
---@return occurrence.Occurrence | nil `nil` if there is no active occurrence for the buffer.
function occurrence.get(buffer)
  local Occurrence = require("occurrence.Occurrence")
  return Occurrence.has(buffer) and Occurrence.get(buffer) or nil
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
  require("occurrence.Config").setup(opts)
end

-- Reset `occurrence.nvim` by removing keymaps
-- and cancelling active occurrences.
-- Automatically called by `setup({})`.
function occurrence.reset()
  require("occurrence.Config").reset()
end

return occurrence
