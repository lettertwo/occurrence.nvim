local Cursor = require("occurrence.Cursor")

local log = require("occurrence.log")

-- A map of Window ids to their cached cursor positions.
---@type table<integer, occurrence.Cursor>
local CURSOR_CACHE = {}

vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("OccurrenceCursorCache", { clear = true }),
  callback = function(args)
    local win_id = tonumber(args.match)
    if win_id and CURSOR_CACHE[win_id] then
      CURSOR_CACHE[win_id] = nil
      log.debug("Cleared cached cursor position for closed window", win_id)
    end
  end,
})

---@type integer?
local watching_dot_repeat

local function watch_dot_repeat()
  if watching_dot_repeat == nil then
    watching_dot_repeat = vim.on_key(function(char)
      if char == "." then
        local win = vim.api.nvim_get_current_win()
        CURSOR_CACHE[win] = Cursor.save()
        log.debug("Updating cached cursor position for dot-repeat to", CURSOR_CACHE[win].location)
      end
    end)
  end
  log.debug("Watching for dot-repeat to cache cursor position")
end

-- Based on https://github.com/neovim/neovim/issues/14157#issuecomment-1320787927
local _set_opfunc = vim.fn[vim.api.nvim_exec2(
  [[
  func! s:set_opfunc(val)
    let &opfunc = a:val
  endfunc
  echon get(function('s:set_opfunc'), 'name')
]],
  { output = true }
).output]

---@class occurrence.OpFuncState
---@field operator string The operator that triggered the opfunc.
---@field count integer The count given to the operator.
---@field register string The register given to the operator.
---@field type? 'char' | 'line' | 'block'
---@field cursor occurrence.Cursor? The cursor position before invoking the operator.
---@field occurrence occurrence.Occurrence? The occurrence being operated on.

---@param state occurrence.OpFuncState The state to pass to the callback.
---@param callback fun(state: occurrence.OpFuncState) The callback to invoke when the opfunc is triggered.
local function set_opfunc(state, callback)
  if state.occurrence then
    log.debug("Caching cursor position for opfunc in buffer", state.occurrence.buffer)
    local cursor = Cursor.save()
    local win = vim.api.nvim_get_current_win()
    CURSOR_CACHE[win] = cursor
  end

  _set_opfunc(function(type)
    state.type = type

    if not state.cursor then
      local win = vim.api.nvim_get_current_win()
      state.cursor = CURSOR_CACHE[win] or Cursor.save()
      state.cursor:restore()
    end

    if callback(state) ~= false then
      -- Reset state to allow dot-repatable operation on a different occurrence.
      state.occurrence = nil
      state.cursor = nil

      -- Watch for dot-repeat to cache cursor position prior to repeating the operation.
      watch_dot_repeat()
    end
  end)
end

return set_opfunc
