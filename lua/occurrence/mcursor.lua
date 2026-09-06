---@module 'occurrence.mcursor'

-- Thin adapter around Neovim's native `:h multicursor` API
-- (`vim.api.nvim_mcursor`, added 2026-09-01, nightly only as of writing).
--
-- Kept in one module so:
--   - the native API is only ever touched here, and
--   - the typecheck job (which runs against stable's `$VIMRUNTIME`,
--     where `nvim_mcursor` is undefined) has one file to ignore.
local log = require("occurrence.log")

local M = {}

local NS_NAME = "nvim.multicursor"

-- Whether the running Neovim exposes the native multicursor API.
-- Indexed by string (not `vim.api.nvim_mcursor`) to avoid an
-- undefined-field warning when typechecking against stable.
---@return boolean
function M.is_supported()
  return vim.api["nvim_mcursor"] ~= nil
end

---@return string
function M.unsupported_message()
  return "Native multicursor requires Neovim 0.13+ with nvim_mcursor()"
end

-- Clamp a `Location`'s column to the last valid (0-indexed) column of its
-- line in `buf`, since `Cursor.move`/`setpos` silently clamps a Normal-mode
-- cursor to that same bound while `nvim_mcursor` accepts a column one past
-- it. Without this, a location one past EOL (e.g. an append-style
-- `range.stop`) ends up on a different column for the primary (clamped by
-- `setpos`) than for the extras (unclamped by `nvim_mcursor`). Consequence:
-- such a location becomes a cursor on the last character of the line, not
-- truly "past" it.
---@param buf integer
---@param location occurrence.Location
---@return occurrence.Location
local function clamp_to_line(buf, location)
  local line = vim.api.nvim_buf_get_lines(buf, location.line, location.line + 1, false)[1] or ""
  local max_col = math.max(#line - 1, 0)
  if location.col <= max_col then
    return location
  end
  return require("occurrence.Location").new(location.line, max_col)
end

-- Pick the index (into `locations`) of the location that should become the
-- primary cursor: the one containing the window cursor, else the nearest
-- one (same line preferred, then smallest absolute line distance), else 1.
---@param locations occurrence.Location[]
---@return integer
local function nearest_primary_index(locations)
  local cursor = require("occurrence.Location").of_cursor()
  if not cursor then
    return 1
  end

  local best_index = 1
  local best_line_distance = math.huge
  local best_col_distance = math.huge
  for i, location in ipairs(locations) do
    if location:eq(cursor) then
      return i
    end
    local line_distance = math.abs(location.line - cursor.line)
    local col_distance = math.abs(location.col - cursor.col)
    if
      line_distance < best_line_distance
      or (line_distance == best_line_distance and col_distance < best_col_distance)
    then
      best_index = i
      best_line_distance = line_distance
      best_col_distance = col_distance
    end
  end
  return best_index
end

-- Convert a list of `Location`s into native cursors.
--
-- One location becomes the primary (ordinary window) cursor; the rest
-- become extra cursors via `nvim_mcursor`. `nvim_mcursor` is a no-op
-- while a cascade is running and errors if any given location's line
-- is out of range, so callers must schedule this after any buffer
-- edits (and after occurrence's own opfunc/feedkeys machinery) have
-- fully settled.
--
-- Locations are deduped first, since `nvim_mcursor` silently ignores
-- duplicate positions but the primary/rest split must still be correct.
---@param locations occurrence.Location[]
---@param opts? { primary?: integer, buf?: integer, follow?: boolean } `primary`: 1-based index of `locations` to use as the primary cursor. `buf`: buffer to operate on (current buffer if omitted); must be valid and current, since moving the window cursor and creating extmarks only make sense for the buffer actually being edited.
function M.add(locations, opts)
  if not M.is_supported() then
    log.error(M.unsupported_message())
    return
  end

  if #locations == 0 then
    return
  end

  local buf = (opts and opts.buf) or 0

  -- `opts.primary` indexes `locations`, but the loop below shortens the list,
  -- so resolve it to a `deduped` index as we go (a primary that duplicates
  -- an earlier location resolves to that earlier entry).
  ---@type integer?
  local primary_index = nil
  ---@type occurrence.Location[]
  local deduped = {}
  do
    ---@type table<string, integer>
    local seen = {}
    for i, location in ipairs(locations) do
      local clamped = clamp_to_line(buf, location)
      local key = clamped:serialize()
      if not seen[key] then
        table.insert(deduped, clamped)
        seen[key] = #deduped
      end
      if opts and opts.primary == i then
        primary_index = seen[key]
      end
    end
  end

  if primary_index == nil then
    primary_index = nearest_primary_index(deduped)
  end

  local primary = deduped[primary_index]
  require("occurrence.Cursor").move(primary)

  for i, location in ipairs(deduped) do
    if i ~= primary_index then
      vim.api["nvim_mcursor"](buf, location:to_markpos())
    end
  end

  -- Follow-mode (`:h q=`) makes motions replay at every cursor. There is no
  -- API for it, only the Normal-mode command, so feed it. `1q=` forces it
  -- on (rather than toggling), which keeps it idempotent even if the
  -- command itself cascades. Skipped when no extra cursor was created,
  -- since there is no session for the flag to belong to.
  if opts and opts.follow and #deduped > 1 then
    vim.api.nvim_feedkeys("1q=", "n", false)
  end
end

-- All native cursor locations in `buf` (current buffer if omitted): the
-- window cursor (only when `buf` is the current buffer) plus every extra
-- cursor, deduped. Returns `{}` immediately when there are no extras, since
-- the primary alone is never "cursors" for import purposes; callers gate
-- on `M.count(buf) > 0` before calling this.
--
-- If `range` is given, only locations contained by it are returned (mirrors
-- Visual `Q` export, which only converts marks inside the selection).
---@param buf? integer
---@param range? occurrence.Range
---@return occurrence.Location[]
function M.locations(buf, range)
  buf = buf or 0
  if M.count(buf) == 0 then
    return {}
  end

  local Location = require("occurrence.Location")
  local ns = vim.api.nvim_create_namespace(NS_NAME)

  ---@type occurrence.Location[]
  local locations = {}
  ---@type table<string, boolean>
  local seen = {}

  local function add(location)
    if not location then
      return
    end
    local key = location:serialize()
    if not seen[key] then
      seen[key] = true
      table.insert(locations, location)
    end
  end

  if buf == vim.api.nvim_get_current_buf() then
    add(Location.of_cursor())
  end

  for _, entry in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
    local _, row, col = unpack(entry)
    add(Location.from_extmarkpos({ row, col }))
  end

  if range then
    locations = vim.tbl_filter(function(location)
      return range:contains(location)
    end, locations)
  end

  return locations
end

-- Number of extra (non-primary) native cursors in `buf` (current buffer if omitted).
---@param buf? integer
---@return integer
function M.count(buf)
  local ns = vim.api.nvim_create_namespace(NS_NAME)
  return #vim.api.nvim_buf_get_extmarks(buf or 0, ns, 0, -1, {})
end

-- Clear all extra native cursors in `buf` (current buffer if omitted).
---@param buf? integer
function M.clear(buf)
  local ns = vim.api.nvim_create_namespace(NS_NAME)
  vim.api.nvim_buf_clear_namespace(buf or 0, ns, 0, -1)
end

return M
