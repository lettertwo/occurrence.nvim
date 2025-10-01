---@class occurrence.Disposable
---@field protected _dispose_stack (function|occurrence.Disposable)[]
---@field protected _disposed boolean
local Disposable = {}

---@param obj any
---@return boolean
local function is_disposable(obj)
  return type(obj) == "table" and type(obj.dispose) == "function"
end

---@param callback? function | occurrence.Disposable
---@return occurrence.Disposable
local function create_disposable(callback)
  local self = { _dispose_stack = {}, _disposed = false }
  setmetatable(self, { __index = Disposable })
  if callback then
    assert(type(callback) == "function" or is_disposable(callback), "Argument must be a Disposable or function")
    table.insert(self._dispose_stack, callback)
  end
  return self
end

-- Dispose all added disposables and functions.
function Disposable:dispose()
  if self._disposed then
    return
  end

  -- Dispose in reverse order of addition.
  for i = #self._dispose_stack, 1, -1 do
    local disposable = self._dispose_stack[i]
    if type(disposable) == "function" then
      disposable()
    elseif type(disposable) == "table" and type(disposable.dispose) == "function" then
      disposable:dispose()
    end
  end

  self._dispose_stack = {}
  self._disposed = true
end

function Disposable:is_disposed()
  return self._disposed
end

-- Add a disposable or function to be called when this is disposed.
---@param disposable occurrence.Disposable | function
---@return occurrence.Disposable
function Disposable:add(disposable)
  assert(not self._disposed, "Cannot add to a disposed Disposable")
  assert(type(disposable) == "function" or is_disposable(disposable), "Argument must be a Disposable or function")
  table.insert(self._dispose_stack, disposable)
  return self
end

---@module "occurrence.Disposable"
local disposable = {
  new = create_disposable,
  is_disposable = is_disposable,
}

return disposable
