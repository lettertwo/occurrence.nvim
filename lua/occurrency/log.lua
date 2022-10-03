---@class OccurencyLog
---@field trace function
---@field debug function
---@field info function
---@field info_once function
---@field warn function
---@field warn_once function
---@field error function
---@field error_once function
---@operator call:string
local log = {}

---@enum LogLevel
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
---@type LogLevel
local current_level = LEVELS.INFO

local PREFIX = "[Occurrency] "
local NOTIFY_OPTIONS = { title = "Occurrency" }

---Prefix and concatenate arguments to a log function.
function log.to_message(...)
  return PREFIX .. table.concat(vim.tbl_flatten({ ... }), " ")
end

--- Sets the current log level.
---@param level LogLevel One of `log.levels`
function log.set_level(level)
  assert(vim.tbl_contains(vim.tbl_values(LEVELS), level), string.format("Invalid log level: %d", level))
  current_level = level
end

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
