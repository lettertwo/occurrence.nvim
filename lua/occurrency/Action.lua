local ACTION = "__ACTION__"

---A callable type that can be used as a keymap callback.
---It can be sequenced with other actions via the `+` operator.
---@class OccurrencyAction
---@operator add((fun(...): nil)|OccurrencyAction): OccurrencyAction
---@operator call(...): nil
---@field type `ACTION`
---@field callback fun(...): nil
local Action = {}

---@param candidate any
---@return boolean
function Action.is_action(candidate)
  return type(candidate) == "table" and candidate.type == ACTION
end

function Action:add(other)
  if type(other) == "function" or self.is_action(other) then
    return self:new(function()
      self()
      other()
    end)
  end
  error("When combining actions, the other must be a function or action")
end

function Action:call(...)
  self.callback(...)
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
