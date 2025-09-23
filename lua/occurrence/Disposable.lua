---@class occurrence.Disposable
---@field protected _dispose_stack (function|occurrence.Disposable)[]
---@field protected _disposed boolean
local Disposable = {}

---@param dispose_fn? function
---@return occurrence.Disposable
local function create_disposable(dispose_fn)
  local self = { _dispose_stack = {}, _disposed = false }
  setmetatable(self, { __index = Disposable })
  if dispose_fn then
    table.insert(self._dispose_stack, dispose_fn)
  end
  return self
end

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

---@param disposable occurrence.Disposable | function
---@return occurrence.Disposable
function Disposable:add(disposable)
  assert(not self._disposed, "Cannot add to a disposed Disposable")
  assert(
    type(disposable) == "function" or (type(disposable) == "table" and type(disposable.dispose) == "function"),
    "Argument must be a Disposable or function"
  )
  table.insert(self._dispose_stack, disposable)
  return self
end

---@module "occurrence.Disposable"
local disposable = {
  new = create_disposable,
}

return disposable
