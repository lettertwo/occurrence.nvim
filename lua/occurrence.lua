---@module 'occurrence'
local occurrence = {}

-- TODO: look at :h SafeState. Is this an event that can help with detecting pending ops?

-- TODO: look at :h command-preview. Can we get inc updating this way?

function occurrence.reset()
  -- We want to allow setup to be called multiple times to reconfigure the plugin.
  -- That means we need to clean up any existing state first.
  local Occurrence = require("occurrence.Occurrence")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    Occurrence.del(buf)
  end
end

---@param opts occurrence.Options
function occurrence.setup(opts)
  opts = opts or {}
  local config = require("occurrence.Config").new(opts)

  local command = require("occurrence.command")
  command.init(config)

  vim.api.nvim_create_user_command("Occurrence", command.execute, {
    nargs = "+",
    desc = "Occurrence command with subcommands",
    force = true,
    complete = command.complete,
    preview = command.preview,
  })

  -- Register global <Plug> mappings for all commands using CapCase convention
  local actions = require("occurrence.actions")

  -- Helper to convert snake_case to CapCase
  local function to_capcase(snake_str)
    local result = snake_str:gsub("_(%w)", function(c)
      return c:upper()
    end)
    return result:sub(1, 1):upper() .. result:sub(2)
  end

  for name, action in pairs(actions) do
    local capcase = to_capcase(name)
    local plug_name = "<Plug>Occurrence" .. capcase
    local cmd = "<Cmd>Occurrence " .. name .. "<CR>"
    local desc = action.desc or ("Occurrence: " .. name)

    -- Normal mode
    vim.keymap.set("n", plug_name, cmd, { desc = desc, silent = true })

    -- Visual mode
    vim.keymap.set("v", plug_name, cmd, { desc = desc, silent = true })

    -- Operator-pending mode (for operator-modifier actions)
    if action.type == "operator-modifier" then
      -- For operator-pending mode, we need to call the wrapped action directly
      -- since expr mappings need to return a value
      local wrapped = config:wrap_action(action)
      vim.keymap.set("o", plug_name, wrapped, { desc = desc, silent = true, expr = true })
    end
  end

  -- Set up default keymaps if user hasn't disabled them
  if config.default_keymaps then
    -- Normal mode default
    vim.keymap.set("n", "go", "<Plug>OccurrenceMarkSearchOrWord", {
      desc = "Mark occurrences of search or word",
    })

    -- Visual mode default
    vim.keymap.set("v", "go", "<Plug>OccurrenceMarkSelection", {
      desc = "Mark occurrences of selection",
    })

    -- Operator-pending mode default
    vim.keymap.set("o", "o", "<Plug>OccurrenceModifyOperator", {
      desc = "Occurrences of word",
    })
  end
end

return occurrence
