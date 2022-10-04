local ACTION = "__ACTION__"
local Occurrence = require("occurrency.Occurrence")

-- A callable type that can be used as a keymap callback.
-- It can be sequenced with other actions via the `+` operator.
-- The callback will receive the Occurrence for the current buffer as its first argument.
-- If the action is sequenced with other actions, the callback will receive the results
-- of the previous action as additional arguments.
---@class OccurrencyAction
---@operator add(OccurrencyAction | fun(occurrence: Occurrence, ...): any): OccurrencyAction
---@operator call(...): any
---@field type `ACTION`
---@field callback fun(occurrence: Occurrence, ...): any
local Action = {}

---@param candidate any
---@return boolean
function Action.is_action(candidate)
  return type(candidate) == "table" and candidate.type == ACTION
end

---@param other OccurrencyAction | fun(occurrence: Occurrence, ...): any
function Action:add(other)
  if type(other) == "function" or self.is_action(other) then
    return self:new(function(occurrence, ...)
      return other(occurrence, unpack({ self(occurrence, ...) }))
    end)
  end
  error("When combining actions, the other must be a function or action")
end

---@param occurrence? Occurrence
function Action:call(occurrence, ...)
  return self.callback(occurrence or Occurrence:new(), ...)
end

-- Convert a function into an action.
---@param callback (fun(...): nil) | OccurrencyAction
---@return OccurrencyAction
function Action:new(callback)
  if self.is_action(callback) then
    ---@cast callback -function
    return callback
  end

  if type(callback) ~= "function" then
    error("callback must be a function")
  end

  return setmetatable({ type = ACTION, callback = callback }, { __index = self, __add = self.add, __call = self.call })
end

-- Convert a table of functions into a table of actions.
---@param module table<string, fun(...): nil>
---@return table<string, OccurrencyAction>
function Action:map(module)
  if type(module) ~= "table" then
    error("module must be a table")
  end
  local result = vim.deepcopy(module)

  for key, value in pairs(module) do
    if type(value) == "function" then
      result[key] = self:new(value)
    end
  end
  return result
end

return Action
