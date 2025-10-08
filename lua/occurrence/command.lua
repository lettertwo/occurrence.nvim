local log = require("occurrence.log")
local api = require("occurrence.api")

---@module "occurrence.command"
local command = {}

---@class occurrence.Subcommand
---@field impl fun(args:string[], opts: vim.api.keyset.create_user_command.command_args) The command implementation
-- :h command-preview
-- Returns an integer:
--   0: No preview is shown
--   1: Preview is shown without preview window (even with "inccommand=split")
--   2: Preview is shown and preview window is opened (if "inccommand=split"; same as 1 for "inccommand=nosplit")
-- nil: same as 2
---@field preview? fun(args: string[], ns: integer, buf: integer?, opts: vim.api.keyset.create_user_command.command_args): 0 | 1 | 2 | nil
-- :h command-completion-custom
---@field complete? fun(subcmd_arg_lead: string, cursorpos: integer): string[] (optional) Command completions callback, taking the lead of the subcommand's arguments

---@type { [string]: occurrence.Subcommand }
local subcommands = {}

-- Create a command impl that wraps a single action
---@param wrapped fun()
---@return fun(args:string[], opts: vim.api.keyset.create_user_command.command_args)
local function create_command_impl(wrapped)
  return function()
    wrapped()
  end
end

-- Register all api actions as commands
---@param config occurrence.Config
local function register_api_commands(config)
  for name, action_config in pairs(api) do
    subcommands[name] = {
      impl = create_command_impl(config:wrap_action(action_config)),
    }
  end
end

---Initialize the command system with the given config
---@param config occurrence.Config
function command.init(config)
  register_api_commands(config)
end

---@param name string
---@param opts occurrence.Subcommand
function command.add(name, opts)
  vim.validate({
    name = { name, "string" },
    opts = { opts, "table" },
    impl = { opts.impl, "function" },
    complete = { opts.complete, "function", true },
  })
  subcommands[name] = opts
end

---@param opts vim.api.keyset.create_user_command.command_args :h lua-guide-commands-create
function command.execute(opts)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]
  local args = #fargs > 1 and { unpack(fargs, 2) } or {}
  local subcommand = subcommands[subcommand_key]
  if not subcommand then
    log.error("Unknown command: " .. tostring(subcommand_key))
    return
  end
  subcommand.impl(args, opts)
end

---@param arglead string The leading portion of the argument being completed
---@param cmdline string The entire command line
---@param cursorpos integer The cursor position in the command line
---@return string[] A list of completion matches
function command.complete(arglead, cmdline, cursorpos)
  local subcommand_key = cmdline:match("^%s*%S+%s+(%S*)")
  if subcommand_key and subcommands[subcommand_key] and subcommands[subcommand_key].complete then
    return subcommands[subcommand_key].complete(arglead, cursorpos)
  end
  return vim.tbl_keys(subcommands)
end

---@param opts vim.api.keyset.create_user_command.command_args :h lua-guide-commands-create
---@param ns integer The namespace id to use for virtual text
---@param buf? integer The buffer number, or `nil` for the current buffer
---@return 0 | 1 | 2
function command.preview(opts, ns, buf)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]
  local subcommand = subcommands[subcommand_key]
  if not subcommand then
    return 0
  end
  if subcommand.preview then
    local args = #fargs > 1 and { unpack(fargs, 2) } or {}
    local result = subcommand.preview(args, ns, buf, opts)
    return type(result) == "number" and math.max(0, math.min(2, result)) or 2
  end
  return 0
end

return command
