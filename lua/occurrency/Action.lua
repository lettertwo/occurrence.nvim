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
---@field args? any
local Action = {}

---@class PartialOccurrencyAction: OccurrencyAction
---@operator add(OccurrencyAction | fun(occurrence: Occurrence, ...): any): OccurrencyAction
---@operator call(...): any
---@field type `ACTION`
---@field callback fun(...): any
---@field args? any

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
---@param callback? (fun(occurrence: Occurrence, ...): nil) | OccurrencyAction
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

-- Binds an existing action to the given occurrence.
-- This is useful for creating actions within actions,
-- e.g., adding keymaps to perform additional actions with an occurrence.
---@param occurrence Occurrence
---@return PartialOccurrencyAction
function Action:with(occurrence)
  local partial = self:new()
  function partial:call(...)
    return self.callback(occurrence, ...)
  end
  getmetatable(partial).__call = partial.call
  ---@cast partial PartialOccurrencyAction
  return partial
end

local function concat(...)
  local args = { ... }
  local result = {}
  for _, arg in ipairs(args) do
    if type(arg) == "table" then
      for _, value in ipairs(arg) do
        table.insert(result, value)
      end
    else
      table.insert(result, arg)
    end
  end
  return result
end

-- Binds an action to some parameters, e.g., config.
-- The first argument to an action is always expected to be an `Occurrence`,
-- so this method is useful for providing additional arguments for an action ahead of time.
-- Note that this differs from `Action.with()` in that it does not bind the occurrence.
---@param ... any
---@return OccurrencyAction
function Action:bind(...)
  local args = select("#", ...) > 0 and { ... } or nil
  if args and self.args then
    args = concat(self.args, args)
  end

  local bound = self:new()
  if args then
    bound.args = args
    function bound:call(occurrence, ...)
      return self.callback(occurrence, unpack(concat(args, ...))) ---@diagnostic disable-line: deprecated
    end
    getmetatable(bound).__call = bound.call
  end
  return bound
end

---@param other OccurrencyAction | fun(occurrence: Occurrence, ...): any
function Action:add(other)
  if type(other) == "function" or self.is_action(other) then
    return self:new(function(occurrence, ...)
      return other(occurrence, unpack({ self(occurrence, ...) })) ---@diagnostic disable-line: deprecated
    end)
  end
  error("When combining actions, the other must be a function or action")
end

---@param occurrence? Occurrence
function Action:call(occurrence, ...)
  return self.callback(occurrence or Occurrence:new(), ...)
end

return Action
