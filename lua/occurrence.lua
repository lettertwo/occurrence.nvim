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

---@module 'occurrence'
local occurrence = {}

-- Generate public API functions and commands for all api functions and
-- register <Plug> mappings for all commands using CapCase convention.
for name, api_config in pairs(api) do
  -- Create `occurrence.<name>` API function
  occurrence[name] = function(config)
    require("occurrence.Occurrence").get():apply(api_config, occurrence.resolve_config(config))
  end

  -- Register `Occurrence <name>` subcommand
  command.add(name, { impl = occurrence[name] })

  -- Register `<Plug>OccurrenceName` keymap
  vim.keymap.set(
    api_config.mode or { "n", "v" },
    api_config.plug or ("<Plug>Occurrence" .. to_capcase(name)),
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

---Initialize a specific buffer by setting up default keymaps if enabled.
---@param buffer integer? The buffer number, or `nil` or `0` for the current buffer
function occurrence.init_buffer(buffer)
  buffer = resolve_buffer(buffer, true)
  local config = occurrence.resolve_config()
  -- TODO: check enabled filetypes here
  if config.default_keymaps then
    -- Normal and visual mode default
    vim.keymap.set({ "n", "v" }, "go", api.find_current.plug, {
      buffer = buffer,
      desc = api.find_current.desc,
    })
    -- Operator-pending mode default
    vim.keymap.set("o", "o", api.modify_operator.plug, {
      buffer = buffer,
      desc = api.modify_operator.desc,
    })
  end
end

---Reset occurrence for a specific buffer.
---@param buffer integer? The buffer number, or `nil` or `0` for the current buffer
function occurrence.reset_buffer(buffer)
  buffer = resolve_buffer(buffer)
  require("occurrence.Occurrence").del(buffer)
  -- Remove default keymaps if they exist
  for _, mode in ipairs({ "n", "v", "o" }) do
    local buf_keymap = vim.api.nvim_buf_get_keymap(buffer, mode)
    for _, km in ipairs(buf_keymap) do
      if km.lhs == "go" and km.rhs == api.find_current.plug then
        pcall(vim.keymap.del, mode, km.lhs, { buf = buffer })
      elseif km.lhs == "o" and km.rhs == api.modify_operator.plug then
        pcall(vim.keymap.del, "o", "o", { buf = buffer })
      end
    end
  end

  occurrence.init_buffer(buffer)
end

--- Reset the occurrence plugin
function occurrence.reset()
  _global_config = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    occurrence.reset_buffer(buf)
  end
end

---@param opts occurrence.Options
function occurrence.setup(opts)
  opts = opts or {}
  local config = require("occurrence.Config").new(opts)

  if _global_config ~= config then
    local had_config = _global_config ~= nil
    _global_config = config
    if had_config then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        occurrence.reset_buffer(buf)
      end
    end
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

-- Register autocmd to initialize buffers on load.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("OccurrenceSetup", { clear = true }),
  callback = function(args)
    occurrence.init_buffer(args.buf)
  end,
})

return occurrence
