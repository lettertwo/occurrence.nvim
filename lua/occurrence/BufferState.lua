local Disposable = require("occurrence.Disposable")

local resolve_buffer = require("occurrence.resolve_buffer")

-- A map of Buffer ids to their BufferCache instances.
---@type table<integer, occurrence.BufferState>
local BUFFER_STATE_CACHE = {}

---@module "occurrence.BufferState"
local buffer_state = {}

---@class occurrence.BufferState: occurrence.Disposable
---@field buffer integer The buffer this state is for.
---@field patterns string[] The active search patterns for the buffer.
---@field protected extmarks occurrence.Extmarks The active extmarks for the buffer.
---@field keymap occurrence.BufferKeymap The active keymap for the buffer.
local BufferState = {}

function BufferState:has_active_keymap()
  return rawget(self, "keymap") ~= nil
end

function BufferState:has_patterns()
  local patterns = rawget(self, "patterns")
  return patterns ~= nil and #patterns > 0
end

function BufferState:clear_patterns()
  local patterns = rawget(self, "patterns")
  if patterns then
    for i = #patterns, 1, -1 do
      table.remove(patterns, i)
    end
  end
end

function BufferState:add_pattern(pattern)
  local patterns = rawget(self, "patterns")
  if patterns == nil then
    patterns = {}
    rawset(self, "patterns", patterns)
  end
  table.insert(patterns, pattern)
end

---@param buffer integer
---@return occurrence.BufferState
local function create_buffer_state(buffer)
  local self = {}
  local disposable = Disposable.new(function()
    if BUFFER_STATE_CACHE[buffer] == self then
      BUFFER_STATE_CACHE[buffer] = nil
    end
    rawset(self, "patterns", nil)
    if rawget(self, "keymap") then
      rawget(self, "keymap"):reset()
      rawset(self, "keymap", nil)
    end
    if rawget(self, "extmarks") then
      rawget(self, "extmarks"):reset()
      rawset(self, "extmarks", nil)
    end
  end)
  setmetatable(self, {
    __index = function(tbl, key)
      if key == "buffer" then
        return buffer
      elseif key == "extmarks" then
        if rawget(tbl, "extmarks") == nil then
          local extmarks = require("occurrence.Extmarks").new(buffer)
          rawset(tbl, "extmarks", extmarks)
        end
        return rawget(tbl, "extmarks")
      elseif key == "keymap" then
        if rawget(tbl, "keymap") == nil then
          local keymap = require("occurrence.Keymap").new(buffer)
          rawset(tbl, "keymap", keymap)
        end
        return rawget(tbl, "keymap")
      elseif key == "patterns" then
        if rawget(tbl, "patterns") == nil then
          local patterns = {}
          rawset(tbl, "patterns", patterns)
        end
        return rawget(tbl, "patterns")
      elseif disposable[key] ~= nil then
        return disposable[key]
      elseif BufferState[key] ~= nil then
        return BufferState[key]
      else
        return rawget(tbl, key)
      end
    end,
    __newindex = function(tbl, key, value)
      if key == "buffer" then
        error("Cannot modify read-only property 'buffer'")
      elseif key == "extmarks" then
        error("Cannot modify read-only property 'extmarks'")
      elseif key == "keymap" then
        error("Cannot modify read-only property 'keymap'")
      elseif key == "patterns" then
        error("Cannot modify read-only property 'patterns'")
      else
        rawset(tbl, key, value)
      end
    end,
  })
  return self
end

---@param buffer? integer
---@return occurrence.BufferState
function buffer_state.get(buffer)
  buffer = resolve_buffer(buffer, true)
  local state = BUFFER_STATE_CACHE[buffer]
  if not state then
    state = create_buffer_state(buffer)
  end
  BUFFER_STATE_CACHE[buffer] = state
  return state
end

function buffer_state.del(buffer)
  local state = BUFFER_STATE_CACHE[buffer]
  if state then
    state:dispose()
  end
  BUFFER_STATE_CACHE[buffer] = nil
end

-- Autocmd to cleanup buffer states when a buffer is deleted.
vim.api.nvim_create_autocmd({ "BufDelete" }, {
  group = vim.api.nvim_create_augroup("OccurrenceBufferStateCleanup", { clear = true }),
  callback = function(args)
    buffer_state.del(args.buf)
  end,
})

return buffer_state
