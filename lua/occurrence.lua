---@module 'occurrence'
local occurrence = {}

local log = require("occurrence.log")

-- TODO: look at :h SafeState. Is this an event that can help with detecting pending ops?

-- TODO: look at :h command-preview. Can we get inc updating this way?

function occurrence.reset()
  -- We want to allow setup to be called multiple times to reconfigure the plugin.
  -- That means we need to clean up any existing state first.
  local BufferState = require("occurrence.BufferState")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    BufferState.del(buf)
  end
end

---@param opts occurrence.Options
function occurrence.setup(opts)
  local Keymap = require("occurrence.Keymap")
  local BufferState = require("occurrence.BufferState")
  local config = require("occurrence.Config").new(opts)
  local actions_config = config:actions()

  local command = require("occurrence.command")
  command.init(config)

  vim.api.nvim_create_user_command("Occurrence", command.execute, {
    nargs = "+",
    desc = "Occurrence command with subcommands",
    force = true,
    complete = command.complete,
    preview = command.preview,
  })

  -- Setup keymaps for normal mode actions.
  Keymap:map_actions("n", config)

  -- Setup keymaps for visual mode actions.
  Keymap:map_actions("v", config)

  -- Setup keymaps for operator-pending mode actions.
  -- Note that these are dynamically bound for supported operators
  -- when entering operator-pending mode.
  if vim.iter(actions_config.o):any(function(_, v)
    return v ~= false
  end) then
    vim.api.nvim_create_autocmd("ModeChanged", {
      pattern = "*:*o",
      group = vim.api.nvim_create_augroup("OccurrenceOperatorPending", { clear = true }),
      callback = function(evt)
        log.debug("ModeChanged to operator-pending")

        local operator = vim.v.operator
        if config:operator_is_supported(operator) then
          local state = BufferState.get(evt.buf)
          -- If a keymap exists, we assume that a preset occurrence is active, so we do nothing.
          if not state:has_active_keymap() then
            state.keymap:map_actions("o", config)
          end
        end
      end,
    })
  end
end

return occurrence
