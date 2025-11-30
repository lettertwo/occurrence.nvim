local log = require("occurrence.log")

---@module "occurrence.command"
local command = {}

---@class occurrence.SubcommandArgs: string[]
---@field count? integer The count prefix given to the command
---@field range? occurrence.Range The range given to the command

---@class occurrence.Subcommand
---@field impl fun(args: occurrence.SubcommandArgs) The command implementation
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

---@param name string
---@param opts occurrence.Subcommand
function command.add(name, opts)
  vim.validate("name", name, "string")
  vim.validate("opts", opts, "table")
  vim.validate("impl", opts.impl, "function")
  vim.validate("complete", opts.complete, "function", true)
  subcommands[name] = opts
end

---@param opts vim.api.keyset.create_user_command.command_args :h lua-guide-commands-create
function command.execute(opts)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]
  local subcommand = subcommands[subcommand_key]
  if not subcommand then
    log.error("Unknown command: " .. tostring(subcommand_key))
    return
  end
  local args = #fargs > 1 and { unpack(fargs, 2) } or {}
  local range = opts.range -- The number of items in the command range: 0, 1 or 2
  if range == 1 then
    args.count = opts.count
  elseif range == 2 then
    local Range = require("occurrence.Range")
    args.range = Range.new(Range.of_line(opts.line1 - 1).start, Range.of_line(opts.line2 - 1).stop)
  end
  subcommand.impl(args)
end

---@param arglead string The leading portion of the argument being completed
---@param cmdline string The entire command line
---@param cursorpos integer The cursor position in the command line
---@return string[]? A list of completion matches
function command.complete(arglead, cmdline, cursorpos)
  local subcommand_key, subcommand_arglead = cmdline:match("^['<,'>]*%S+[!]*%s+(%S*)%s(.*)$")
  if subcommand_key and subcommands[subcommand_key] and subcommands[subcommand_key].complete then
    return subcommands[subcommand_key].complete(subcommand_arglead, cursorpos)
  elseif arglead and not subcommand_key or not subcommands[subcommand_key] then
    -- `:Occurrence <TAB>` or `:Occurrence <subcommand> <TAB>`
    return vim.tbl_keys(subcommands)
  end
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
