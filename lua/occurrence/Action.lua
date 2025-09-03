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

---@module 'occurrence.Action'
local action = {}

-- A callable type that can be used as a keymap callback.
-- It can be sequenced with other actions via the `+` operator.
-- The callback will receive the `Occurrence` for the current buffer as its first argument.
-- If the action is sequenced with other actions, the callback will receive the results
-- of the previous action as additional arguments.
---@class occurrence.Action
---@operator add(occurrence.Action | fun(occurrence: occurrence.Occurrence, ...): any): occurrence.Action
---@overload fun(occurrence: occurrence.Occurrence?, ...): any
---@field protected type `ACTION`
---@field protected callback fun(occurrence: occurrence.Occurrence, ...): any
---@field protected args? any
local Action = {}

-- An action that is bound to a specific `Occurrence`.
-- and does not expect to be called with an `Occurrence` argument.
-- It can be sequenced with other actions via the `+` operator,
-- but note that the bound occurrence will be passed to the subsequent action
-- _unless_ that action is also bound to an `Occurrence`.
--
---@class occurrence.OccurrenceAction: occurrence.Action
---@operator add(occurrence.Action | fun(occurrence: occurrence.Occurrence, ...): any): occurrence.OccurrenceAction
---@overload fun(...): any
---@field new fun(callback?: (fun(occurrence: occurrence.Occurrence, ...): nil) | occurrence.Action, ...: any): self
---@field bind fun(...: any): self
---@field protected occurrence occurrence.Occurrence

local function is_occurrence_action(value)
  return type(value) == "table" and pcall(value.is_action, value) and value.occurrence ~= nil
end

---@param candidate any
---@return boolean
function action.is_action(candidate, ...)
  if select("#", ...) > 0 then
    error("no arguments expected")
  end
  return type(candidate) == "table" and candidate.type == ACTION
end

function Action:is_action()
  return true
end

-- Create a new action from a callback or existing action.
-- If the `callback` is a function (or other callable), the new action will wrap it.
-- If the `callback` is an action, the new action will extend it.
---@param callback (fun(occurrence: occurrence.Occurrence, ...): any) | occurrence.Action
---@return occurrence.Action
function action.new(callback)
  assert(callback, "Action must have a callback")

  local self = { type = ACTION }
  local meta = Action
  if action.is_action(callback) then
    -- If the callback is an action, we just extend it.
    ---@cast callback -function
    meta = callback
  elseif not is_callable(callback) then
    error("callback must be callable")
  else
    self.callback = callback
  end

  return setmetatable(self, {
    __index = meta,
    __add = meta.add, ---@diagnostic disable-line: invisible
    __call = meta.call, ---@diagnostic disable-line: invisible
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
---@param occurrence occurrence.Occurrence
---@return occurrence.OccurrenceAction
function Action:with(occurrence)
  local bound = action.new(self)
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
  ---@cast bound occurrence.OccurrenceAction
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

  local bound = action.new(self)

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
---@param left occurrence.Action | fun(occurrence: occurrence.Occurrence, ...): any
---@param right occurrence.Action | fun(occurrence: occurrence.Occurrence, ...): any
---@return self
function Action.add(left, right)
  if is_callable(right) then
    if is_occurrence_action(left) and is_occurrence_action(right) then
      local combined = action.new(left)
      function combined:call(...)
        return right(unpack({ left(...) }))
      end
      getmetatable(combined).__call = combined.call
      return combined
    elseif is_occurrence_action(left) then
      local combined = action.new(left)
      function combined:call(...)
        ---@diagnostic disable-next-line: undefined-field
        return right(left.occurrence, unpack({ left(...) }))
      end
      getmetatable(combined).__call = combined.call
      return combined
    elseif is_occurrence_action(right) then
      return action.new(function(occurrence, ...)
        return right(unpack({ left(occurrence, ...) }))
      end)
    else
      return action.new(function(occurrence, ...)
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
---@param occurrence? occurrence.Occurrence
function Action:call(occurrence, ...)
  return self.callback(occurrence or Occurrence.new(), ...)
end

return action
