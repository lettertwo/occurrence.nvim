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
  local actions = require("occurrence.actions")
  local operators = require("occurrence.operators")
  local config = require("occurrence.Config").new(opts)
  local actions_config = config:actions()

  -- Setup keymaps for normal mode actions.
  for key, action in pairs(actions_config.n) do
    local resolved_action = actions.resolve(action)
    if resolved_action then
      Keymap:n(key, resolved_action:bind(config), { desc = actions.get_desc(resolved_action, "n") })
    elseif action ~= false then
      if type(action) == "string" then
        log.warn_once("No action '" .. action .. "' found for keymap '" .. key .. "' in normal mode")
      else
        log.warn_once("Invalid action for keymap '" .. key .. "' in normal mode")
      end
    end
  end

  -- Setup keymaps for visual mode actions.
  for key, action in pairs(actions_config.v) do
    ---@type occurrence.Action?
    local resolved_action = actions.resolve(action)
    if resolved_action then
      Keymap:v(key, resolved_action:bind(config), { desc = actions.get_desc(resolved_action, "v") })
    elseif action ~= false then
      if type(action) == "string" then
        log.warn_once("No action '" .. action .. "' found for keymap '" .. key .. "' in visual mode")
      else
        log.warn_once("Invalid action for keymap '" .. key .. "' in visual mode")
      end
    end
  end

  -- Setup keymaps for operator-pending mode actions.
  -- Note that these are dynamically bound for supported operators
  -- when entering operator-pending mode.
  if vim.iter(actions_config.o):any(function(_, v)
    return v ~= false
  end) then
    vim.api.nvim_create_autocmd("ModeChanged", {
      pattern = "*:*o",
      callback = function(evt)
        log.debug("ModeChanged to operator-pending")
        -- If a keymap exists, we assume that a preset occurrence is active, so we do nothing.
        if not Keymap.get(evt.buf) then
          local keymap = Keymap.new(evt.buf)
          local operator = vim.v.operator
          if operators.is_supported(operator, config) then
            for key, action in pairs(actions_config.o) do
              local resolved_action = actions.resolve(action)
              if resolved_action then
                keymap:o(key, resolved_action:bind(config), { desc = actions.get_desc(resolved_action, "o") })
              elseif action ~= false then
                if type(action) == "string" then
                  log.warn_once(
                    "No action '" .. action .. "' found for keymap '" .. key .. "' in operator-pending mode"
                  )
                else
                  log.warn_once("Invalid action for keymap '" .. key .. "' in operator-pending mode")
                end
              end
            end
          end
        end
      end,
    })
  end
end

return occurrence
