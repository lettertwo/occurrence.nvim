---@class OccurencyLog
---@field trace function
---@field debug function
---@field info function
---@field info_once function
---@field warn function
---@field warn_once function
---@field error function
---@field error_once function
local log = {}

local LEVELS = vim.log.levels

-- Default log level is WARN.
local current_level = LEVELS.WARN

local PREFIX = "[Occurrency] "
local NOTIFY_OPTIONS = { title = "Occurrency" }

---Prefix and concatenate arguments to a log function.
function log.to_message(...)
  return PREFIX .. table.concat(vim.tbl_flatten({ ... }), " ")
end

--- Sets the current log level.
---@param level number One of `vim.log.levels`
function log.set_level(level)
  assert(type(level) == "number", "level must be a number or string")
  assert(LEVELS[level], string.format("Invalid log level: %d", level))
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

return log
