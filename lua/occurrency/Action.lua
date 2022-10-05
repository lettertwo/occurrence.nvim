local ACTION = "__ACTION__"
local Occurrence = require("occurrency.Occurrence")
local log = require("occurrency.log")

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

-- Create a new action from a callback or existing action.
-- If the `callback` is a function, the new action will wrap it.
-- If the `callback` is an action, the new action will extend it.
-- If the `callback` is `nil`, the new action will extend the current action. This only works
-- for existing actions.
---@param callback? (fun(...): nil) | OccurrencyAction
---@return OccurrencyAction
function Action:new(callback)
  local action = { type = ACTION }
  local meta = self
  if callback == nil then
    assert(self.callback, "Action must have a callback")
  elseif self.is_action(callback) then
    -- If the callback is an action, we just extend it.
    ---@cast callback -function
    meta = callback
  elseif type(callback) ~= "function" then
    error("callback must be a function")
  else
    action.callback = callback
  end

  return setmetatable(action, { __index = meta, __add = meta.add, __call = meta.call })
end

-- Binds an existing action to the given arguments.
-- The first argument is expected to be an `Occurrence`.
-- This is useful for creating actions within actions,
-- e.g., adding keymaps to perform additional actions with an occurrence.
---@param occurrence Occurrence
---@param ... any
---@return OccurrencyAction
function Action:bind(occurrence, ...)
  local args = select("#", ...) > 0 and { ... } or nil
  local bound = self:new()
  function bound:call(...)
    if args then
      return self.callback(occurrence, unpack(args), ...)
    else
      return self.callback(occurrence, ...)
    end
  end
  getmetatable(bound).__call = bound.call
  return bound
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
