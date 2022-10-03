local create_action = require("occurrency.action").create_action
local mark = require("occurrency.mark")
local log = require("occurrency.log")

---@enum OccurrencyKeymapMode
local MODE = {
  n = "n", ---Normal mode.
  o = "o", ---Operator-pending mode.
  x = "x", ---Visual or select mode.
}

-- Creates a table that maps modes to active keymaps.
---@return table<OccurrencyKeymapMode, string[]>
local function create_active_map()
  local modemap = {}
  setmetatable(modemap, {
    __index = function(_, key)
      assert(MODE[key], "Invalid mode: " .. key)
      local mode = rawget(modemap, key)
      if mode == nil then
        mode = {}
        rawset(modemap, key, mode)
      end
      return mode
    end,
  })
  return modemap
end

-- The globally active keymaps.
local ACTIVE_KEYMAPS = create_active_map()

-- The buffer-local variable that stores active keymaps.
local BUF_ACTIVE_KEYMAP_VAR = "occurrency_active_keymaps"

---@param bufnr integer
local function get_or_create_buf_active_map(bufnr)
  local ok, buf_active_map = pcall(vim.api.nvim_buf_get_var, bufnr, BUF_ACTIVE_KEYMAP_VAR)
  if not ok or buf_active_map == nil then
    buf_active_map = create_active_map()
    log.debug("Created buffer-local active keymap table for buffer " .. bufnr)
    vim.api.nvim_buf_set_var(bufnr, BUF_ACTIVE_KEYMAP_VAR, buf_active_map)
  end
  return buf_active_map
end

---@param bufnr integer
local function clear_buf_active_map(bufnr)
  local ok, buf_active_map = pcall(vim.api.nvim_buf_get_var, bufnr, BUF_ACTIVE_KEYMAP_VAR)
  if not ok or buf_active_map == nil then
    log.debug("No buffer bindings to deactivate")
    return
  end
  log.debug(vim.inspect(buf_active_map))
  for mode, bindings in pairs(buf_active_map) do
    for _, lhs in ipairs(bindings) do
      log.debug("Deactivating buffer binding", mode, lhs)
      if not pcall(vim.keymap.del, mode, lhs, { buffer = bufnr }) then
        log.warn("Failed to unmap " .. mode .. " " .. lhs)
      end
    end
    buf_active_map[mode] = nil
  end
  vim.api.nvim_buf_del_var(bufnr, BUF_ACTIVE_KEYMAP_VAR)
end

local M = {}

--- Wraps an action in a function so that it can be used as a keymap callback.
---@param action string | function | OccurrencyAction
---@return string | function
function M.wrap_action(action)
  if type(action) == "table" then
    return function()
      return action()
    end
  end
  ---@cast action -OccurrencyAction
  return action
end

-- Parse keymap options.
---@param opts table | string
---@return table #options with any defaults applied.
function M.parse_opts(opts)
  if type(opts) == "string" then
    return { desc = opts }
  end
  return opts
end

-- Register a normal mode keymap.
---@param lhs string
---@param rhs string | function | OccurrencyAction
---@param opts table | string
function M.n(lhs, rhs, opts)
  vim.keymap.set(MODE.n, lhs, M.wrap_action(rhs), M.parse_opts(opts))
  table.insert(ACTIVE_KEYMAPS[MODE.n], lhs)
end

-- Register an operator-pending mode keymap.
---@param lhs string
---@param rhs string | function | OccurrencyAction
---@param opts table | string
function M.o(lhs, rhs, opts)
  vim.keymap.set(MODE.o, lhs, M.wrap_action(rhs), M.parse_opts(opts))
  table.insert(ACTIVE_KEYMAPS[MODE.o], lhs)
end

-- Register a visual or select mode keymap.
---@param lhs string
---@param rhs string | function | OccurrencyAction
---@param opts table | string
function M.x(lhs, rhs, opts)
  vim.keymap.set(MODE.x, lhs, M.wrap_action(rhs), M.parse_opts(opts))
  table.insert(ACTIVE_KEYMAPS[MODE.x], lhs)
end

-- Resets all keymaps registered by this module.
function M.reset()
  for mode, bindings in pairs(ACTIVE_KEYMAPS) do
    for _, lhs in ipairs(bindings) do
      if not pcall(vim.keymap.del, mode, lhs) then
        log.warn("Failed to unmap " .. mode .. " " .. lhs)
      end
    end
    ACTIVE_KEYMAPS[mode] = nil
  end
end

-- Creates an action to activate keybindings for the given configuration and mode.
---@param mode OccurrencyKeymapMode
---@param config OccurrencyConfig
---@return OccurrencyAction
function M.activate(mode, config)
  assert(MODE[mode], "Invalid mode: " .. mode)
  return create_action(function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    log.debug("Activating keybindings for buffer", bufnr, "and mode", mode)
    local buf_active_map = get_or_create_buf_active_map(bufnr)
    -- TODO: mode-specific bindings

    -- Bind these regardless of the mode we're activating.
    -- TODO: Make this configurable.
    -- FIXME: bufvars might be readonly... seems we have to set the buf_active_map after every binding.
    -- Maybe we extract the global keymap behavior to be bindable to a buffer?
    vim.keymap.set(MODE.n, "<Esc>", M.wrap_action(mark.clear + M.deactivate), { buffer = bufnr })
    table.insert(buf_active_map[MODE.n], "<Esc>")
    log.debug("Activated buffer bindings", vim.inspect(buf_active_map))
  end)
end

-- Deactivate keybindings for the given buffer.
-- If no buffer is given, the current buffer is used.
---@param bufnr integer
M.deactivate = create_action(function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  log.debug("Deactivating keybindings for buffer", bufnr)
  clear_buf_active_map(bufnr)
end)

return M
