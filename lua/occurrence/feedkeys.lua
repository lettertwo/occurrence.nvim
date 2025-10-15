---@module 'occurrence.feedkeys'

---@class occurrence.FeedkeysOptions
---@field noflush? boolean if `true`, do not flush the typeahead
---@field noremap? boolean if `true`, do not remap keys

---@class occurrence.ChangeModeOptions
---@field silent? boolean if `true`, suppress `:h ModeChanged` event
---@field force? boolean if `true`, force the mode change even if already in the desired mode
---@field noflush? boolean if `true`, do not flush the typeahead

-- Feedkeys with termcodes replaced.
-- By default, flushes the typeahead and remaps keys
-- (`mx` mode for `:h feedkeys()`).
-- Note that this is different from `:h feedkeys()`'s default behavior,
-- which is to not flush the typeahead.
--
-- If `opts.noflush` is `true`, do not flush the typeahead.
-- If `opts.noremap` is `true`, do not remap keys.
---@class occurrence.feedkeys
---@overload fun(keys: string, opts?: occurrence.FeedkeysOptions)
local feedkeys = setmetatable({}, {
  ---@param keys string
  ---@param opts? occurrence.FeedkeysOptions
  __call = function(_, keys, opts)
    keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
    local mode = opts and opts.noremap and "n" or "m"
    mode = mode .. (opts and opts.noflush and "" or "x")
    vim.api.nvim_feedkeys(keys, mode, false)
  end,
})

-- Feed the necessary keys to change the mode.
-- If `mode` is `"n"`, `"i"`, `"v"`, `"V"`, `"^V"`, or `"o"`, change to that mode.
-- If already in that mode, do nothing.
-- If the mode is `"i"`, `:h startinsert` is used rather than feeding keys.
-- If the mode is `"o"`, `"g@"` is used to enter operator-pending mode,
-- and the typeahead is not flushed (to allow for the motion to be fed next).
-- Any other string is passed to feedkeys as is.
--
-- If `opts.silent` is `true`, the `ModeChanged` event is suppressed.
-- If `opts.force` is `true`, force the mode change even if already in the desired mode
-- (has no effect if `mode` is `"n"` or `"i"`).
-- `opts.noflush` defaults to `true` for `"o"` mode only.
---@param mode "n" | "i" | "v" | "V"| "^V"| "o" | string
---@param opts? occurrence.ChangeModeOptions
function feedkeys.change_mode(mode, opts)
  -- normalize mode strings
  if mode == "^V" then
    mode = ""
  elseif mode == "g@" then
    mode = "o"
  end

  -- `noflush=true` only for operator-pending mode by default.
  local feedkeys_opts = { noremap = true, noflush = mode == "o" }
  if opts and opts.noflush ~= nil then
    feedkeys_opts.noflush = opts.noflush
  end

  local eventignore = nil
  if opts and opts.silent then
    eventignore = vim.o.eventignore
    vim.o.eventignore = "ModeChanged"
    vim.o.eventignore = eventignore
  end

  if mode == "n" then
    if not vim.api.nvim_get_mode().mode:match("n") or opts and opts.force then
      feedkeys("<C-\\><C-n>", feedkeys_opts)
    end
  elseif mode == "i" then
    vim.cmd.startinsert()
  elseif mode == "v" or mode == "V" or mode == "" then
    local current_mode = vim.api.nvim_get_mode().mode
    if not current_mode:match(mode) or opts and opts.force then
      if not current_mode:match("n") then
        feedkeys("<C-\\><C-n>", { noflush = true })
      end
      feedkeys(mode, feedkeys_opts)
    end
  elseif mode == "o" then
    local current_mode = vim.api.nvim_get_mode().mode
    if not current_mode:match("o") or opts and opts.force then
      if not current_mode:match("n") then
        feedkeys("<C-\\><C-n>", { noflush = true })
      end
      feedkeys("g@", feedkeys_opts)
    end
  else
    feedkeys(mode, feedkeys_opts)
  end

  if eventignore then
    vim.o.eventignore = eventignore
  end
end

-- Flush the typeahead buffer.
function feedkeys.flush()
  vim.api.nvim_feedkeys("", "nx", false)
end

return feedkeys
