local ACTION = "__ACTION__"
local Occurrence = require("occurrence.Occurrence")

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

local function is_callable(callback)
  if type(callback) == "function" then
    return true
  end
  local cb_meta = getmetatable(callback)
  if cb_meta ~= nil then
    return is_callable(cb_meta.__call)
  end
  return false
end

-- A callable type that can be used as a keymap callback.
-- It can be sequenced with other actions via the `+` operator.
-- The callback will receive the `Occurrence` for the current buffer as its first argument.
-- If the action is sequenced with other actions, the callback will receive the results
-- of the previous action as additional arguments.
---@class Action
---@operator add(Action | fun(occurrence: Occurrence, ...): any): Action
---@overload fun(occurrence: Occurrence?, ...): any
---@field protected type `ACTION`
---@field protected callback fun(occurrence: Occurrence, ...): any
---@field protected args? any
local Action = {}

-- An action that is bound to a specific `Occurrence`.
-- and does not expect to be called with an `Occurrence` argument.
-- It can be sequenced with other actions via the `+` operator,
-- but note that the bound occurrence will be passed to the subsequent action
-- _unless_ that action is also bound to an `Occurrence`.
--
---@class OccurrenceAction: Action
---@operator add(Action | fun(occurrence: Occurrence, ...): any): OccurrenceAction
---@overload fun(...): any
---@field new fun(callback?: (fun(occurrence: Occurrence, ...): nil) | Action, ...: any): self
---@field bind fun(...: any): self
---@field protected occurrence Occurrence

local function is_occurrence_action(action)
  return type(action) == "table" and pcall(action.is_action, action) and action.occurrence ~= nil
end

---@param candidate any
---@return boolean
function Action.is_action(candidate, ...)
  if select("#", ...) > 0 then
    error("no arguments expected")
  end
  return type(candidate) == "table" and candidate.type == ACTION
end

-- Create a new action from a callback or existing action.
-- If the `callback` is a function (or other callable), the new action will wrap it.
-- If the `callback` is an action, the new action will extend it.
---@param callback (fun(occurrence: Occurrence, ...): any) | Action
---@return self
function Action.new(callback)
  assert(callback, "Action must have a callback")

  local action = { type = ACTION }
  local meta = Action
  if Action.is_action(callback) then
    -- If the callback is an action, we just extend it.
    ---@cast callback -function
    meta = callback
  elseif not is_callable(callback) then
    error("callback must be callable")
  else
    action.callback = callback
  end

  return setmetatable(action, {
    __index = meta,
    __add = meta.add,
    __call = meta.call,
  })
end

-- Binds an existing action to the given occurrence.
-- This is useful for creating actions within actions,
-- e.g., adding keymaps to perform additional actions with an occurrence.
--
-- Note that the resulting action does not expect to be called with
-- an `Occurrence` argument.
--
-- If this is action is combined with another action, it will forward
-- the bound occurrence to the next action _unless_ that action
-- is also bound to an `Occurrence`.
--
---@param occurrence Occurrence
---@return OccurrenceAction
function Action:with(occurrence)
  local bound = self:new()
  local callback = self.callback
  local args = self.args
  if args ~= nil then
    function bound:call(...)
      return callback(bound.occurrence, unpack(concat(args, ...)))
    end
  else
    function bound:call(...)
      return callback(bound.occurrence, ...)
    end
  end
  getmetatable(bound).__call = bound.call
  ---@cast bound OccurrenceAction
  ---@diagnostic disable-next-line: invisible
  bound.occurrence = occurrence
  return bound
end

-- Binds an action to some parameters, e.g., config.
-- The first argument to an action is always expected to be an `Occurrence`,
-- so this method is useful for providing additional arguments for an action ahead of time.
--
-- Note that this differs from `Action.with()` in that it does not bind the occurrence,
-- and it will not forward its bound arguments to any combined actions.
--
---@param ... any
---@return self
function Action:bind(...)
  local args = select("#", ...) > 0 and {
    ...,
  } or nil
  if args and self.args then
    args = concat(self.args, args)
  end

  local bound = self:new()

  if args then
    bound.args = args

    local callback = self.callback

    if is_occurrence_action(self) then
      local occurrence = self.occurrence ---@diagnostic disable-line: undefined-field
      function bound:call(...)
        return callback(occurrence, unpack(concat(args, ...)))
      end
    else
      function bound:call(occurrence, ...)
        return callback(occurrence, unpack(concat(args, ...)))
      end
    end
    getmetatable(bound).__call = bound.call
  end

  return bound
end

-- Combines two actions into a single action.
-- When called, the unified action will unpack the result of _this_ action as arguments to the `other` action.
--
-- This is normally invoked by using the `+` operator, not called directly.
--
---@protected
---@param left Action | fun(occurrence: Occurrence, ...): any
---@param right Action | fun(occurrence: Occurrence, ...): any
---@return self
function Action.add(left, right)
  if is_callable(right) then
    if is_occurrence_action(left) and is_occurrence_action(right) then
      local combined = left:new()
      function combined:call(...)
        return right(unpack({ left(...) }))
      end
      getmetatable(combined).__call = combined.call
      return combined
    elseif is_occurrence_action(left) then
      local combined = left:new()
      function combined:call(...)
        ---@diagnostic disable-next-line: undefined-field
        return right(left.occurrence, unpack({ left(...) }))
      end
      getmetatable(combined).__call = combined.call
      return combined
    elseif is_occurrence_action(right) then
      return Action.new(function(occurrence, ...)
        return right(unpack({ left(occurrence, ...) }))
      end)
    else
      return Action.new(function(occurrence, ...)
        return right(occurrence, unpack({ left(occurrence, ...) }))
      end)
    end
  end
  error("When combining actions, the other must be a callable or action")
end

-- Calls the action's callback with the given arguments.
-- The first argument is expected to be an `Occurrence` or `nil`.
-- If an occurrence is not provided, a new occurrence will be created.
--
-- This is normally invoked by using the `()` operator, not called directly.
--
---@protected
---@param occurrence? Occurrence
function Action:call(occurrence, ...)
  return self.callback(occurrence or Occurrence:new(), ...)
end

return Action
