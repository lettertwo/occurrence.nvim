local Occurrence = require("occurrence.Occurrence")
local Operator = require("occurrence.Operator")
local Range = require("occurrence.Range")

local log = require("occurrence.log")
local set_opfunc = require("occurrence.set_opfunc")

---@module "occurrence.OperatorModifier"

-- Function to be used as a callback for an operator modifier action.
-- The first argument will always be the `Occurrence` for the current buffer.
-- The second argument will be the current `Config`.
-- If the function returns `false`, the operator modifier activation will be cancelled.
---@alias occurrence.OperatorModifierCallback fun(occurrence: occurrence.Occurrence, config: occurrence.Config): false | nil

-- An action that will activate operator-pending keymaps after running.
---@class (exact) occurrence.OperatorModifierConfig
---@field desc? string
---@field callback? occurrence.OperatorModifierCallback

---@param candidate any
---@return boolean
local function is_operator_modifier(candidate)
  return type(candidate) == "table" and candidate.type == "operator-modifier"
end

---@param occurrence occurrence.Occurrence
---@param occurrence_config occurrence.Config
local function modify_operator(occurrence, occurrence_config)
  local operator, count, register = vim.v.operator, vim.v.count, vim.v.register
  local operator_config = occurrence_config:get_operator_config(operator)

  if not operator_config then
    log.warn("Operator not supported:", operator)
    return
  end

  log.debug("Activating operator-pending keymaps for buffer", occurrence.buffer)

  -- Set up buffer-local operator-pending escape keymaps
  local deactivate = function()
    occurrence:dispose()
  end

  vim.keymap.set("o", "<Esc>", deactivate, {
    buffer = occurrence.buffer,
    desc = "Clear occurrence",
  })
  occurrence:add_keymap("o", "<Esc>")

  vim.keymap.set("o", "<C-c>", deactivate, {
    buffer = occurrence.buffer,
    desc = "Clear occurrence",
  })
  occurrence:add_keymap("o", "<C-c>")

  vim.keymap.set("o", "<C-[>", deactivate, {
    buffer = occurrence.buffer,
    desc = "Clear occurrence",
  })
  occurrence:add_keymap("o", "<C-[>")

  set_opfunc({
    operator = operator,
    count = count,
    register = register,
    occurrence = occurrence,
  }, function(state)
    state.count = vim.v.count > 0 and vim.v.count or state.count
    state.register = vim.v.register

    if not state.occurrence then
      state.occurrence = Occurrence.new()
      assert(occurrence_config:get_action_config("mark_word")).callback(state.occurrence, occurrence_config)
    end

    Operator.apply(
      state.occurrence,
      operator_config,
      state.operator,
      Range.of_motion(state.type),
      state.count,
      state.register,
      state.type
    )

    state.occurrence:dispose()
  end)

  -- Schedule sending `g@` to trigger custom opfunc on the next frame.
  -- This is async to allow the first mode change event to cycle.
  -- If we did this synchronously, there would be no opportunity for
  -- other plugins (e.g. which-key) to react to the modified operator mode change.
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.schedule(function()
    -- re-enter operator-pending mode
    vim.api.nvim_feedkeys("g@", "n", true)
  end)
  -- send <C-\><C\n> immediately to cancel pending op.
  -- see `:h CTRL-\_CTRL-N` and `:h g@`
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
end

---@param config occurrence.OperatorModifierConfig
---@param occurrence_config occurrence.Config
---@return function
local function create_operator_modifier(config, occurrence_config)
  return function()
    local occurrence = Occurrence.new()
    local ok, result = pcall(config.callback, occurrence, occurrence_config)
    if not ok or result == false then
      log.debug("Operator modifier cancelled")
      occurrence:dispose()
      return
    end

    return modify_operator(occurrence, occurrence_config)
  end
end

return {
  new = create_operator_modifier,
  is = is_operator_modifier,
  activate = modify_operator,
}
