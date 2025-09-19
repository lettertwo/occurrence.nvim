---@module 'occurrence'
local occurrence = {}

local log = require("occurrence.log")

-- TODO: look at :h SafeState. Is this an event that can help with detecting pending ops?

-- TODO: look at :h command-preview. Can we get inc updating this way?

function occurrence.reset()
  -- We want to allow setup to be called multiple times to reconfigure the plugin.
  -- That means we need to clean up any existing state first:
  -- 1. Clear any existing keymaps.
  local Keymap = require("occurrence.Keymap")
  Keymap:reset()
  -- 2. Clear any buffer-local keymaps.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    Keymap.del(buf)
  end
end

---@param opts occurrence.Options
function occurrence.setup(opts)
  local Keymap = require("occurrence.Keymap")
  local config = require("occurrence.Config").new(opts)
  local actions_config = config:actions()

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
        -- If a keymap exists, we assume that a preset occurrence is active, so we do nothing.
        if not Keymap.get(evt.buf) then
          local keymap = Keymap.new(evt.buf, config)
          local operator = vim.v.operator
          if config:operator_is_supported(operator) then
            keymap:map_actions("o")
          else
            log.warn_once("Operator '" .. operator .. "' is not supported")
          end
        end
      end,
    })
  end
end

return occurrence
