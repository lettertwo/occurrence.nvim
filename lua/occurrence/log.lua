---@module 'occurrence.log'
---@class occurrence.log
---@field trace fun(...): nil
---@field debug fun(...): nil
---@field info fun(...): nil
---@field info_once fun(...): nil
---@field warn fun(...): nil
---@field warn_once fun(...): nil
---@field error fun(...): nil
---@field error_once fun(...): nil
---@operator call:string
---@overload fun(...): nil
local log = {}

---@enum occurrence.LogLevel
local LEVELS = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  OFF = 5,
}

log.levels = LEVELS

-- Default log level is INFO.
---@type occurrence.LogLevel
local current_level = LEVELS.INFO

local NOTIFY_OPTIONS = { title = "Occurrence" }

---Prefix and concatenate arguments to a log function.
---@param ... any
---@return string
function log.to_message(...)
  return table.concat(vim.tbl_map(tostring, { ... }), " ")
end

--- Sets the current log level.
---@param level occurrence.LogLevel One of `log.levels`
function log.set_level(level)
  assert(vim.tbl_contains(vim.tbl_values(LEVELS), level), string.format("Invalid log level: %d", level))
  current_level = level
end

---@return occurrence.LogLevel
function log.get_level()
  return current_level
end

do
  for level, levelnr in pairs(LEVELS) do
    if levelnr ~= LEVELS.OFF then
      log[level:lower()] = function(...)
        if levelnr >= current_level then
          vim.notify(log.to_message(...), levelnr, NOTIFY_OPTIONS)
        end
      end
      if levelnr > LEVELS.DEBUG then
        log[level:lower() .. "_once"] = function(...)
          if levelnr >= current_level then
            vim.notify_once(log.to_message(...), levelnr, NOTIFY_OPTIONS)
          end
        end
      end
    end
  end
end

setmetatable(log, {
  __call = function(_, ...)
    log.info(...)
  end,
})

return log
