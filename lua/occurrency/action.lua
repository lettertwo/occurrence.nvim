local M = {}

local ACTION = "__ACTION__"

---A callable type that can be used as a keymap callback.
---It can be sequenced with other actions via the `+` operator.
---@class OccurrencyAction
---@operator add((fun(...): nil)|OccurrencyAction): OccurrencyAction
---@operator call: nil
---@field type `ACTION`
---@field callback fun(...): nil

local ACTION_META = {
  __add = function(self, other)
    if type(other) == "function" or M.is_action(other) then
      return M.create_action(function()
        self()
        other()
      end)
    end
    error("When combining actions, the other must be a function or action")
  end,
  __call = function(self, ...)
    self.callback(...)
  end,
}

---@param candidate any
---@return boolean
function M.is_action(candidate)
  return type(candidate) == "table" and candidate.type == ACTION
end

---Convert a function into an action.
---@param callback (fun(...): nil) | OccurrencyAction
---@return OccurrencyAction
function M.create_action(callback)
  if M.is_action(callback) then
    ---@cast callback -function
    return callback
  end

  if type(callback) ~= "function" then
    error("callback must be a function")
  end

  local action = { type = ACTION, callback = callback }
  setmetatable(action, ACTION_META)
  return action
end

---Convert a table of functions into a table of actions.
---@param module table<string, fun(...): nil>
---@return table<string, OccurrencyAction>
function M.create_actions(module)
  if type(module) ~= "table" then
    error("module must be a table")
  end
  local result = vim.deepcopy(module)

  for key, value in pairs(module) do
    if type(value) == "function" then
      result[key] = M.create_action(value)
    end
  end
  return result
end

return M
